module Chorus
  # Maps a Role's durable skill REQUIREMENTS (names/slugs) to installable skill
  # SOURCES the Equipper can mount. This is the layer where "which catalog row
  # satisfies this requirement right now" lives — deliberately NOT an FK on the Role
  # (§4), so a catalog refresh can never break a Role definition.
  #
  # STUBBED in 007. It echoes each requirement as an as-if-resolved source against a
  # single default repo, so both the dry wiring spec (argv assertion) and the live
  # seed run (a genuinely installable vercel-labs/agent-skills skill) work off the
  # same path. The DEFERRED work lands HERE later (where it belongs): real
  # CatalogSkill/Curation resolution plus the curation policy (curation_enabled /
  # reputation_threshold gating, nil/unreviewed treatment).
  class SkillResolver
    # A resolved skill the Equipper mounts: `resource` is the git repo `npx skills`
    # installs from, `skill` the skill within it, `name` the originating requirement.
    ResolvedSkill = Struct.new(:name, :resource, :skill, keyword_init: true)

    # STUB: the repo every requirement resolves to until real catalog resolution
    # lands. The seed's requirements (web-design-guidelines, frontend-design) are
    # real skills in this repo, so a live equip actually installs them.
    STUB_RESOURCE = "vercel-labs/agent-skills".freeze

    def initialize(role)
      @role = role
    end

    # role requirements -> [ResolvedSkill]. Name-only requirements become
    # (STUB_RESOURCE, name) pairs; real resolution + policy replaces this.
    #
    # Queries SkillRequirement directly rather than through Role: plan 010 §2
    # dropped `Role has_many :skill_requirements` (skills now attach via RoleSkill),
    # but SkillRequirement stays inert and still keyed by role.
    def resolve
      Chorus::SkillRequirement.where(role: @role).map do |requirement|
        ResolvedSkill.new(name: requirement.name, resource: STUB_RESOURCE, skill: requirement.name)
      end
    end
  end
end
