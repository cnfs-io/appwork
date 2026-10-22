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

    # The workspace's markdown scope (plan 011 §6): a VIEWPORT into a host-seeded
    # bundle — the bundle's root or any path inside it — rather than a bundle the
    # workspace creates for itself (which is why 010's has_one_okf :bundle and its
    # materialize_bundle/doc_pathname machinery are gone; this avoids one bundle per
    # workspace). The viewport is markdown-only: work orders, plans, results live
    # here; code changes land in the Sources. Concept paths are bundle-relative, so
    # they carry the viewport's own path within the bundle as a prefix.
    has_one_okf :view_port

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
  end
end
