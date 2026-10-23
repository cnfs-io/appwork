module Appwork
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
    # It reads Appwork::Chorus::Config#skills_live at the shell boundary (§8): when dry, it
    # records the `npx skills add ...` argv it WOULD have run (and the cwd it would run
    # in) into the Result and returns without installing. When live, it really installs
    # and then CONFIRMS the skill landed — a failed install, or an "exited 0 but the
    # skill isn't there" miss, is recorded into the durable Result and success flipped
    # to false (§5), never raised. A silent equip miss (the agent later runs without
    # its skill) is worse than a crash.
    #
    # PARKED (plan 011 §8/§12): the Result rewrite removed the argv/failure accumulator
    # this used to record into. Equipper is inert until the foreman loop replaces it —
    # its Result coupling was stripped rather than ported (the new per-invocation Result
    # is not an accumulator). It still installs skills project-scoped when skills_live,
    # and is otherwise a no-op. The `result:` argument is retained only so the existing
    # (dead) Invocation constructor keeps matching.
    class Equipper
      def initialize(adapter:, result: nil, workspace:, catalog: SkillCatalog.new)
        @adapter   = adapter
        @result    = result
        @workspace = workspace
        @catalog   = catalog
      end

      # Equip each resolved skill; installs project-scoped into the workspace when
      # skills_live, a no-op otherwise. Returns whatever `result:` it was handed.
      def equip(resolved_skills)
        Array(resolved_skills).each { |skill| equip_one(skill) }
        @result
      end

      private

      def equip_one(skill)
        return unless Appwork::Chorus::Config.skills_live

        @catalog.add(skill.resource, skill: skill.skill, agents: agents,
                     path: @workspace.pathname)
      end

      def agents
        [ @adapter.skills_agent_key ]
      end
    end
  end
end
