module Chorus
  # The durable outcome of an invocation. AR-backed and persisted on EVERY run —
  # live or dry — so a run always leaves behind queryable rows (§5): the Result
  # never vanishes the way a PORO would.
  #
  # Its INTERFACE is modeled on ActiveModel::Errors — it accumulates keyed messages
  # (`add(:category, msg)`), answers `empty?` / `success?`, produces `full_messages`,
  # and `merge`s cleanly when several contributors write into one Result — but the
  # backing is a `chorus_results` row, not a transient object. That shape is what
  # makes goals 4–5 fall out structurally: an evaluator empaneling and returning
  # assessments is the same operation as validation — each `#add`s findings into the
  # shared (persisted) Result, `collate` reads the merged collection, delivery gates
  # on `success?` the way `save` gates on `valid?`. Because Result and its Artifact
  # are durable from day one, a future evaluator can be handed the SAME Artifact and
  # append to the SAME Result across time.
  #
  # NOTE (007 scope): this plan builds Result + Artifact REVIEW-READY, not reviewed.
  # Do NOT add `has_many :reviews` here — the Review model lands with plan 008; a
  # polymorphic has_many with no chorus_reviews table would dangle.
  class Result < ApplicationRecord
    belongs_to :artifact,  optional: true   # a dry/aborted run may have a placeholder/no output
    belongs_to :workspace, optional: true   # where the run happened

    after_initialize do
      self.messages      ||= {}
      self.recorded_argv ||= []
    end

    # --- ActiveModel::Errors-shaped message surface --------------------------

    # Append a keyed message. Chainable; returns self so contributors compose.
    def add(category, message)
      key = category.to_s
      self.messages = messages.merge(key => Array(messages[key]) + [ message.to_s ])
      self
    end

    # True when no messages have accumulated (mirrors Errors#empty?).
    def empty?
      messages.values.all? { |msgs| Array(msgs).empty? }
    end

    # ["category message", ...] — every accumulated message, category-prefixed.
    def full_messages
      messages.flat_map { |category, msgs| Array(msgs).map { |m| "#{category} #{m}" } }
    end

    # Merge another Result (or a raw { category => [msg] } bag) into this one — the
    # evaluator-readiness path: several contributors compose into one Result.
    def merge(other)
      bag = other.is_a?(Result) ? other.messages : other
      bag.to_h.each { |category, msgs| Array(msgs).each { |m| add(category, m) } }
      self
    end

    # Gates delivery the way `valid?` gates `save`. Reads the recorded outcome when
    # set; falls back to "no messages accumulated" when the invocation left it nil.
    def success?
      success.nil? ? empty? : success
    end

    # --- argv recording (dry-run inspectability, §8) -------------------------

    # Record the argv a phase ran (or WOULD have run, in dry mode). `phase` is
    # :equip (npx skills add ...) or :invoke (claude -p ... / opencode run ...).
    # # 009 `cwd:` records the working directory the command ran in — the run's
    # materialized Workspace directory — so the recorded run shows BOTH what ran
    # (`-y`, the flags) and WHERE (the project path), not just the bare argv.
    def record_argv(phase, argv, cwd: nil)
      entry = { "phase" => phase.to_s, "argv" => Array(argv).map(&:to_s) }
      entry["cwd"] = cwd.to_s if cwd
      self.recorded_argv = recorded_argv + [ entry ]
      self
    end

    # The argv arrays recorded for a given phase (convenience for specs/console).
    def argv_for(phase)
      recorded_argv.select { |entry| entry["phase"] == phase.to_s }.map { |entry| entry["argv"] }
    end

    # The working directories recorded for a given phase (the project paths).
    def cwd_for(phase)
      recorded_argv.select { |entry| entry["phase"] == phase.to_s }.map { |entry| entry["cwd"] }
    end
  end
end
