module Okf
  module Consumer
    extend ActiveSupport::Concern

    class_methods do
      # owns_many_okf :bundles
      # owns_many_okf :reference_docs, class_name: "Okf::Concept"
      def owns_many_okf(name, class_name: nil)
        has_many name,
                 class_name: class_name || okf_class_for(name),
                 as: :owner, dependent: :destroy, inverse_of: :owner
      end

      # owns_one_okf :concept
      # owns_one_okf :root_bundle, class_name: "Okf::RootBundle"
      def owns_one_okf(name, class_name: nil)
        has_one name,
                class_name: class_name || okf_class_for(name),
                as: :owner, dependent: :destroy, inverse_of: :owner
      end

      private

      # :bundles -> "Okf::Bundle", :concept -> "Okf::Concept"
      def okf_class_for(name) = "Okf::#{name.to_s.classify}"
    end
  end
end
