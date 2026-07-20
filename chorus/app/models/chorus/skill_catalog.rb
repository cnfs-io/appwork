module Chorus
  # The one place that shells out to the `npx skills` CLI, and the population
  # mechanism for Chorus::CatalogSkill. A plain service object (not a model, not a
  # concern): the catalog data lives in CatalogSkill rows; this object only fetches
  # and parses.
  #
  # The shell boundary is a single private seam — #npx — over CnfsSupport::Shell
  # (array form, no shell interpolation, separated stdout/stderr, timeout,
  # non-raising). It is the SOLE swap point if the CLI is ever replaced by an
  # HTTP/registry call — the public verb wrappers know nothing about how npx is
  # invoked. Verbs that parse output read #merged_output(result); verbs that only
  # care about the effect check the result's #success?.
  #
  # npx's textual output is NOT a stable API, so parsing is best-effort and
  # isolated: each parser is a small private method with its own unit spec fed
  # committed fixture strings, and parsers never run inside the shell seams (seams
  # capture raw text; parsers interpret it).
  #
  # # 004 deferred: workspace materialization — the on-demand copy/format of chosen
  # skills into a Workspace for a specific AgentAdapter (the `-a <agent>` path
  # targeting a workspace directory) — is the day-to-day runtime act and a separate
  # design (ephemeral setup vs a recorded SkillInstallation join). #add exposes the
  # `-a`/`path:` plumbing; it does not record a materialization.
  # # 004 deferred: the relevance lens (scoring catalog skills against the tenant's
  # OKF-derived vocabulary) and curation policy (how Chorus::Config's
  # curation_enabled/reputation_threshold gate the catalog) both consume this
  # mirror later; neither is built here.
  class SkillCatalog
    # --- Public verb wrappers -------------------------------------------------

    # Search the registry by keyword (matches name + description upstream). Returns
    # a structured list [{resource:, skill_name:, description:, install_count:}].
    # Description is often absent from `find` output (nil) — it is filled in by
    # #list_repo_skills or a later mirror pass.
    def search(query, owner: nil)
      args = [ "find", query.to_s ]
      args += [ "--owner", owner.to_s ] if owner.present?
      parse_find(merged_output(npx(*args)))
    end

    # Enumerate the skills a repo exposes WITHOUT installing. Returns
    # [{resource:, skill_name:, description:}], the resource stamped in from the
    # argument (the `--list` output itself names only the skills).
    def list_repo_skills(resource)
      out = merged_output(npx("add", resource.to_s, "--list"))
      parse_repo_skills(out).map { |skill| skill.merge(resource: resource.to_s) }
    end

    # Install a repo or a single skill. Project/path-scoped by default: `path:` is the
    # working directory the install lands in, and because a path exists the install is
    # project-scoped — NEVER passes -g unless global: true is asked for explicitly.
    # `-y` is UNCONDITIONAL (§4) — an unattended harness must never block on npx's
    # confirm prompt. `--copy` follows Chorus::Config.skill_copy (copy vs symlink).
    def add(resource, path: nil, **opts)
      npx(*add_args(resource, **opts), chdir: path)
    end

    # The `add` sub-argv (everything after `npx skills`) for these options — the
    # SINGLE source of truth shared by #add (which runs it) and Chorus::Equipper
    # (which records it in dry mode via #npx_argv), so the recorded and the run
    # commands can never drift. `-y` always; `--copy` per config; `-g` only on
    # explicit global.
    def add_args(resource, skill: nil, agents: [], global: false, copy: Chorus::Config.skill_copy)
      args = [ "add", resource.to_s, "-y" ]
      args += [ "--skill", skill.to_s ] if skill.present?
      Array(agents).each { |agent| args += [ "-a", agent.to_s ] }
      args << "--copy" if copy
      args << "-g" if global
      args
    end

    # The full `npx skills …` argv these args produce, WITHOUT running it. Public so
    # Chorus::Equipper can record the exact command a live equip would run.
    def npx_argv(*args)
      [ "npx", "skills", *args.map(&:to_s) ]
    end

    # Refresh installed skills. scope: :global -> -g, :project -> -p.
    def update(*names, scope: nil)
      args = [ "update", *names.map(&:to_s) ]
      args << scope_flag(scope) if scope
      npx(*args)
    end

    # Remove installed skills (optionally from specific agent dirs).
    def remove(name, agents: [])
      args = [ "remove", name.to_s ]
      Array(agents).each { |agent| args += [ "-a", agent.to_s ] }
      npx(*args)
    end

    # Scaffold a new skill. `chdir:` runs the scaffold in that directory.
    def init(name = nil, chdir: nil)
      args = [ "init" ]
      args << name.to_s if name.present?
      npx(*args, chdir: chdir)
    end

    # Mirror-refresh entry point: upsert CatalogSkill rows on the natural key
    # [resource, skill_name] from #search / #list_repo_skills output, stamping
    # synced_at. A second ingest of the same skill UPDATES rather than duplicates.
    # Mirror/clobber is safe — nothing tenant-authored lives on CatalogSkill.
    def ingest(entries)
      now = Time.current
      Array(entries).map do |entry|
        record = CatalogSkill.find_or_initialize_by(
          resource: entry[:resource], skill_name: entry[:skill_name]
        )
        record.description   = entry[:description] if entry.key?(:description) && !entry[:description].nil?
        record.install_count = entry[:install_count] if entry.key?(:install_count) && !entry[:install_count].nil?
        record.repo_topics   = entry[:repo_topics] if entry.key?(:repo_topics) && !entry[:repo_topics].nil?
        record.synced_at = now
        record.save!
        record
      end
    end

    private

    def scope_flag(scope)
      case scope.to_sym
      when :global  then "-g"
      when :project then "-p"
      else raise ArgumentError, "unknown scope: #{scope.inspect}"
      end
    end

    # --- Parsers (best-effort; npx output is not a stable API) -----------------

    # `find` emits, per hit, a line "owner/repo@skill  <N> installs" followed by a
    # "└ https://skills.sh/..." line, wrapped in ANSI color. We take the first
    # line of each pair. A hit without an @skill segment is a whole-repo entry
    # (skill_name nil).
    def parse_find(output)
      strip_ansi(output).each_line.filter_map do |line|
        m = line.match(%r{^(?<owner>[\w.-]+/[\w.-]+?)(?:@(?<skill>[\w.:-]+))?\s+(?<count>[\d.]+\s*[KM]?)\s+installs}i)
        next unless m

        { resource: m[:owner], skill_name: m[:skill], description: nil,
          install_count: parse_install_count(m[:count]) }
      end
    end

    # `add <repo> --list` prints, after an "Available Skills" header, clack-boxed
    # pairs: a bare skill-name line, then an indented description line, each gutter-
    # prefixed with "│". Names are single tokens; descriptions carry spaces — that
    # is the discriminator. Everything before the header is spinner/status noise
    # and is ignored.
    def parse_repo_skills(output)
      _before, _header, listing = strip_ansi(output).partition("Available Skills")
      return [] if listing.empty?

      skills = []
      listing.each_line do |raw|
        # Only gutter-prefixed ("│") lines are skill content; trailing status
        # lines (e.g. "◇  Use --skill ...") carry no gutter and are ignored so
        # they can't be mistaken for a description.
        next unless raw.include?("│")

        content = raw.sub(/^[^\S\n]*│/, "").strip   # drop the clack gutter
        next if content.empty?

        if content.match?(/\A[\w][\w.:-]*\z/)         # single token -> a skill name
          skills << { skill_name: content, description: nil }
        elsif skills.any?                             # prose -> the current skill's description
          skills.last[:description] =
            [ skills.last[:description], content ].compact.join(" ")
        end
      end
      skills
    end

    # "541.8K" -> 541_800, "4K" -> 4_000, "1.2M" -> 1_200_000, "37" -> 37.
    def parse_install_count(str)
      return nil if str.nil?

      m = str.strip.match(/\A(?<n>[\d.]+)\s*(?<unit>[KM]?)/i)
      return nil unless m

      mult = { "k" => 1_000, "m" => 1_000_000 }[m[:unit].downcase] || 1
      (m[:n].to_f * mult).round
    end

    # Strip CSI/ANSI escape sequences (colors, cursor moves, mode toggles) so the
    # parsers see plain text regardless of the terminal noise npx emits.
    def strip_ansi(text)
      text.to_s.gsub(/\e\[[0-9;?]*[ -\/]*[@-~]/, "")
    end

    # --- Shell boundary -------------------------------------------------------

    # The SOLE swap point: one seam over CnfsSupport::Shell. The old run_* (side
    # effect) / capture_* (output) split collapses — a single call returns the
    # normalized Shell::Result carrying BOTH the effect and the captured output,
    # non-raising. Callers that only care about the effect check #success?; callers
    # that parse read #merged_output. Array form, no shell; `chdir:` scopes the
    # working directory (project-scoped installs / scaffolds land there). The
    # `cnfs_chorus.skill_catalog.npx_exec` event is preserved by wrapping the
    # adapter (which emits its own `cnfs_support.shell.run` span inside).
    def npx(*args, chdir: nil)
      argv = npx_argv(*args)
      instrument(:npx_exec, cmd: argv.join(" ")) do
        CnfsSupport::Shell.run(*argv, cwd: chdir)
      end
    end

    # The captured text the parsers consume: stdout with stderr appended, matching
    # the err-merged stream the pre-Shell IO.popen boundary fed them (npx writes
    # spinner/status noise the parsers must see and skip).
    def merged_output(result)
      "#{result.stdout}#{result.stderr}"
    end

    # Emit all SkillCatalog instrumentation under a stable
    # `cnfs_chorus.skill_catalog.<verb>` prefix (mirrors Source/ExternalAccount).
    # Never place a token, credential, or unbounded blob in the payload.
    def instrument(verb, **payload, &block)
      name = CnfsSupport::Instrumentable.event_name("Chorus::SkillCatalog", verb)
      ActiveSupport::Notifications.instrument(name, **payload, &block)
    end
  end
end
