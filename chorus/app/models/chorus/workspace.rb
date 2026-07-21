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
    # A plot of land carries the role it was provisioned for (plan 011 §6).
    belongs_to :role

    # The WorkOrder currently occupying this place — the serial-occupancy claim slot
    # (§6). Optional: an unclaimed workspace holds none.
    belongs_to :current_work_order, class_name: "Chorus::WorkOrder", optional: true

    # Every work order that has landed against this place. Nullify: a work order
    # outlives the teardown of the place it ran in.
    has_many :work_orders, dependent: :nullify

    # The sources (repos) checked out into this workspace — the place owns them
    # (plan 011 §6). Nullify on destroy: a source outlives the place it sat in.
    has_many :sources, as: :owner, dependent: :nullify

    # The OKF bundle rooted at the workspace's `doc/` — where authored documents
    # (Plans, and later Tasks/notes) live as Concepts. Materialized on demand via
    # #materialize_bundle (plan 010 §4).
    has_one_okf :bundle

    validates :name, presence: true

    # Take serial occupancy of this workspace for `work_order` — an atomic
    # conditional update that writes the claim only when the slot is free. Returns
    # true on success, false when another work order already holds it (0 rows
    # updated). One work order active at a time: a resumed CLI conversation is not
    # concurrency-safe, so two turns against one thread must never both hold the same
    # workspace — the check is a WHERE on `current_work_order_id: nil`, not a Ruby
    # guard, so concurrent claimants race in the database and exactly one wins (plan
    # 011 §6). The stale-claim reaper (a worker dying mid-turn holds the claim
    # forever otherwise) is deferred.
    def claim!(work_order)
      won = self.class.where(id: id, current_work_order_id: nil)
                .update_all(current_work_order_id: work_order.id, claimed_at: Time.current)
      return false unless won == 1

      reload
      true
    end

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
