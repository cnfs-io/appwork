module Chorus
  # chorus.org's central verdict about a skill, distributed as a YAML whitelist on
  # GitHub and loaded into each tenant's DB. Tenants consume it READ-ONLY — they
  # never edit reputation; they only set their own threshold (a config value, see
  # Chorus::Config), not a column here.
  #
  # Three-state reputation, expressed by ROW PRESENCE:
  #   * row absent   -> nil    -> chorus.org rendered NO verdict (unknown)
  #   * reputation 0 -> reviewed and trash/dangerous (RCE, lies about behavior).
  #                     0 is the bottom of the scale, NOT a hard block — Chorus is
  #                     not in the business of preventing use. Any "hard to install
  #                     a 0" behavior is UI/policy, out of scope here.
  #   * 1..100       -> graded quality.
  # Do not collapse 0 and nil: they answer opposite questions ("known bad" vs
  # "unknown").
  #
  # Refresh discipline is load/clobber via CnfsSupport::YamlSerializable — tenants
  # author nothing here, so clobber-reload on update is safe. Joins CatalogSkill on
  # the natural key [resource, skill_name]; either side may exist without the other.
  #
  # Account-scoped by tenancy (one physical DB per Account), so no owner column.
  #
  # # 004 deferred: local (tenant-side) reputation — a per-tenant, outcome-derived
  # score distinct from chorus.org's global number, plus the return path that feeds
  # ratings back up to chorus.org — is a second axis for later. Today there is the
  # single global `reputation` field only; do NOT add a local score here yet.
  class Curation < ApplicationRecord
    include CnfsSupport::YamlSerializable

    validates :resource, presence: true
    # A PRESENT row must carry a score in 0..100 (inclusion rejects nil): the
    # "unknown/no verdict" state is row ABSENCE, never a present row with a null
    # reputation. That keeps nil (unknown) and 0 (known bad) from ever colliding.
    validates :reputation, inclusion: { in: 0..100 }

    # The mirrored catalog row this verdict is about, resolved on the natural key
    # (not a FK). May be nil: chorus.org can hold a verdict on a skill this tenant
    # has not mirrored locally yet.
    def catalog_skill
      CatalogSkill.find_by(resource: resource, skill_name: skill_name)
    end
  end
end
