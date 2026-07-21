module Chorus
  # Mounts a set of resolved skills onto ONE agent runtime, INTO the run's workspace
  # directory (§4). Mounting is runtime-PARAMETERIZED, not runtime-polymorphic (§2):
  # each Agent runtime subclass declares only its `skills_agent_key`, and this one
  # shared PORO drives SkillCatalog#add once per skill, passing
  # `agents: [adapter.skills_agent_key]` and `path: workspace.pathname` — so the
  # install is project-scoped into the workspace (no `-g`, no `~/.claude` pollution),
  # unattended (`-y`), copy-or-symlink per config. The Equipper owns NO shell of its
  # own — SkillCatalog owns the `npx` boundary.
  #
  # It reads Chorus::Config#skills_live at the shell boundary (§8): when dry, it
  # records the `npx skills add ...` argv it WOULD have run (and the cwd it would run
  # in) into the Result and returns without installing. When live, it really installs
  # and then CONFIRMS the skill landed — a failed install, or an "exited 0 but the
  # skill isn't there" miss, is recorded into the durable Result and success flipped
  # to false (§5), never raised. A silent equip miss (the agent later runs without
  # its skill) is worse than a crash.
  class Equipper
    # npx was observed to print a not-found message yet still exit 0. Exit code alone
    # is therefore not trustworthy; we also scan the output for this signal. A
    # heuristic on unstable CLI text — deliberately narrow to avoid false positives.
    SKILL_NOT_FOUND = /no matching skills? found|skills? not found|couldn't find|could not find/i

    def initialize(adapter:, result:, workspace:, catalog: SkillCatalog.new)
      @adapter   = adapter
      @result    = result
      @workspace = workspace
      @catalog   = catalog
    end

    # Equip each resolved skill; returns the Result (argv + cwd recorded on it, and
    # any equip failures accumulated as messages).
    def equip(resolved_skills)
      Array(resolved_skills).each { |skill| equip_one(skill) }
      @result
    end

    private

    def equip_one(skill)
      args = @catalog.add_args(skill.resource, skill: skill.skill, agents: agents)
      # Record the exact would-run command AND where it runs (the project path), from
      # the SkillCatalog builders — so the record can never drift from a live run.
      @result.record_argv(:equip, @catalog.npx_argv(*args), cwd: @workspace.directory)
      return unless Chorus::Config.skills_live

      shell = @catalog.add(skill.resource, skill: skill.skill, agents: agents,
                           path: @workspace.pathname)
      confirm_installed(skill, shell)
    end

    def agents
      [ @adapter.skills_agent_key ]
    end

    # Record an operational failure into the Result (never raise): a non-zero install,
    # or a zero-exit that nonetheless reported the skill was not found.
    def confirm_installed(skill, shell)
      if !shell.success?
        fail_equip(skill, shell.failure_message)
      elsif "#{shell.stdout}#{shell.stderr}".match?(SKILL_NOT_FOUND)
        fail_equip(skill, "npx exited 0 but reported the skill was not found")
      end
    end

    def fail_equip(skill, detail)
      @result.add(:equip, "#{skill.resource} #{skill.skill}: #{detail}")
      @result.success = false
    end
  end
end
