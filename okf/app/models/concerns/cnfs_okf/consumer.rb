module CnfsOkf
  module Consumer
    extend ActiveSupport::Concern

    class_methods do
      def has_many_okf(name, class_name: nil)
        has_many name,
                 class_name: class_name || okf_class_for(name),
                 as: :owner, dependent: :destroy, inverse_of: :owner
      end

      def has_one_okf(name, class_name: nil)
        has_one name,
                class_name: class_name || okf_class_for(name),
                as: :owner, dependent: :destroy, inverse_of: :owner
      end

      # Declares that this consumer surfaces custom-frontmatter key(s) from its
      # owned :concept as instance accessors. Both read and write delegate
      # through the concept's serialized custom_frontmatter Hash (string keys).
      # Replaces the hand-written priority/priority= pair in the dummy models.
      #
      # Concept-first assumption: the write accessor calls
      # `concept.custom_frontmatter=` with no nil-guard on `concept` itself,
      # because a consumer that declares okf_frontmatter is expected to own a
      # concept (has_one_okf :concept). Absence is a consumer bug, not a case to
      # defend. The read accessor is nil-safe (`&.`) so a not-yet-materialized
      # concept reads nil rather than raising — matching the current hand-written
      # behavior.
      def okf_frontmatter(*names)
        names.each do |name|
          key = name.to_s
          define_method(name) { concept&.custom_frontmatter&.dig(key) }
          define_method(:"#{name}=") do |value|
            concept.custom_frontmatter = (concept.custom_frontmatter || {}).merge(key => value)
          end
        end
      end

      private

      # :bundles -> "CnfsOkf::Bundle", :concept -> "CnfsOkf::Concept"
      def okf_class_for(name) = "CnfsOkf::#{name.to_s.classify}"
    end
  end
end
