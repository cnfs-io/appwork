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
  end
end
