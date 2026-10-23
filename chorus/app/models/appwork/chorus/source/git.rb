module Appwork
  module Chorus
    class Source
      # Git-backed source. `resource` is the clone URL; `ref` tracks the last-synced
      # commit SHA; `branch` (in the settings bag) selects what to track.
      #
      # The transport methods shell out to git. They are deliberately thin — Chorus
      # coordinates the clone/pull, it does not reimplement git. Efficacy (that a
      # real clone succeeds against a real remote) is a host-app concern and is not
      # exercised by Chorus's own suite.
      #
      # The shell boundary is two private seams — #run_git (side effects) and
      # #capture_git (output). They shell out to the `git` binary today; swapping
      # to a git library later touches only these two methods, since the public
      # transport interface (#fetch/#refresh/#current_ref) knows nothing about how
      # git is invoked.
      class Git < Source
        setting :branch

        def fetch
          instrument(:fetch, source_id: id, resource: resource, path: path) do
            args = [ "clone" ]
            args += [ "--branch", branch ] if branch.present?
            args += [ resource, path ]
            run_git(*args)
            record_synced!
          end
        end

        def refresh
          instrument(:refresh, source_id: id, path: path, tracking_ref: tracking_ref) do
            run_git("-C", path, "fetch", "--all", "--prune")
            run_git("-C", path, "reset", "--hard", tracking_ref)
            record_synced!
          end
        end

        # The commit SHA the tracked ref currently points at on the remote, without
        # cloning or fetching. Returns nil if the ref does not exist upstream.
        #
        # `ls-remote` emits one "SHA\trefname" line per matching ref. A single ref
        # name can yield several lines — notably an annotated tag produces both the
        # tag object and its peeled commit (refname with a "^{}" suffix). We resolve
        # to the commit: prefer the peeled line when present, else the plain match.
        def current_ref
          instrument(:current_ref, source_id: id, resource: resource, tracking_ref: tracking_ref) do
            refs = parse_ls_remote(capture_git("ls-remote", resource, tracking_ref))
            next if refs.empty?

            peeled = refs.find { |name, _| name.end_with?("^{}") }
            (peeled || refs.first).last
          end
        end

        private

        def tracking_ref = branch.presence || "HEAD"

        def record_synced!
          head = capture_git("-C", path, "rev-parse", "HEAD").strip
          update!(ref: head, synced_at: Time.current)
        end

        # Parses "SHA\trefname" lines into [[refname, sha], ...], skipping blanks
        # and any malformed line that lacks the tab separator.
        def parse_ls_remote(output)
          output.each_line.filter_map do |line|
            sha, name = line.strip.split("\t", 2)
            [ name, sha ] if name && sha.present?
          end
        end

        # --- Shell boundary -------------------------------------------------------

        # Run git for its side effects; raise on failure. Array form, no shell.
        def run_git(*args)
          instrument(:git_exec, cmd: [ "git", *args ].map(&:to_s).join(" ")) do
            system("git", *args.map(&:to_s), exception: true)
          end
        end

        # Run git and return stdout; raise on failure with git's stderr for context.
        # Array form via IO.popen — no shell, so nothing in args is interpreted.
        def capture_git(*args)
          argv = [ "git", *args.map(&:to_s) ]
          instrument(:git_exec, cmd: argv.join(" ")) do
            out = IO.popen(argv, err: [ :child, :out ], &:read)
            next out if $?.success?

            raise "#{argv.join(' ')} failed (#{$?.exitstatus}): #{out.strip}"
          end
        end
      end
    end
  end
end
