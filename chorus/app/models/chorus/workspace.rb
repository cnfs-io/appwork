require "pathname"

module Chorus
  # The durable, serial execution surface: it occupies ONE polymorphic workable at
  # a time and owns the Artifacts a run produces. Top-level root — scoped by the
  # database (one physical DB per Account IS one organization), never by an owner FK.
  #
  # # 009 A Workspace also IS a real directory on disk — the single anchor for
  # everything physical about a run: the agent's working directory (`cwd`), the home
  # for project-scoped skills, and where captured output lands. The directory is
  # derived deterministically from the workspace id (stable across runs) under the
  # host-configured `Chorus::Config.workspace_root`, and materialized on demand.
  # 009 only gives it a path and creates it lazily; it NEVER deletes — teardown /
  # archival timing is entangled with session/claim work and is deferred
  # (doc/plans/003-heartbeat-and-checkout.md).
  class Workspace < ApplicationRecord
    # A workspace occupies at most one workable at a time (a polymorphic target).
    belongs_to :workable, polymorphic: true, optional: true

    has_many :artifacts, dependent: :destroy

    # The OKF bundle rooted at the workspace's `doc/` — where authored documents
    # (Plans, and later Tasks/notes) live as Concepts. Materialized on demand via
    # #materialize_bundle (plan 010 §4).
    has_one_okf :bundle

    validates :name, presence: true

    # The directory this Workspace IS on disk — materialized on demand (idempotent
    # mkpath, memoized so it happens once per instance). The single value callers
    # ask for: the Equipper installs skills into it, and the AgentProfile runs with
    # it as `cwd`. Never deleted here.
    def pathname
      materialize
    end

    # Create the workspace directory if absent and return it. Lazy: the first caller
    # that needs the directory brings it into being. Idempotent — safe to call
    # repeatedly; existing contents are left untouched.
    def materialize
      @pathname ||= directory.tap(&:mkpath)
    end

    # The pure path derivation — no disk side effect, deterministic from the id.
    # Under the host-configured root (with `~` expanded), keyed by id so the same
    # workspace always maps to the same directory across process runs.
    def directory
      raise "Workspace must be persisted before it has a pathname" unless persisted?

      root = Pathname.new(File.expand_path(Chorus::Config.workspace_root))
      root.join(id.to_s)
    end

    # The `doc/` subtree under this workspace — the root the OKF bundle is rooted at.
    # Rooted at `doc/`, NOT the workspace root: the bundle syncs every `**/*.md`
    # beneath its path, so rooting at the workspace root would eventually pull in
    # installed skill markdown as concepts. `doc/` keeps the bundle scoped to
    # authored documents, and makes concept paths bundle-relative (a file at
    # `<workspace>/doc/plans/001-x.md` has concept.path == "plans/001-x.md").
    def doc_pathname = pathname.join("doc")

    # Materialize the workspace dir + `doc/`, then find-or-create the Bundle rooted
    # at `doc/`. Idempotent — a second call returns the existing bundle. The dir
    # MUST exist before the Bundle is created: Bundle validates `dev` presence (set
    # from `stat`), so create against a missing directory fails validation — hence
    # mkpath first. `create_concepts` runs Sync on create; on an empty `doc/` that
    # is a no-op.
    def materialize_bundle
      doc_pathname.mkpath
      bundle || create_bundle!(path: doc_pathname.to_s)
    end
  end
end
