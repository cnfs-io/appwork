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

      private

      # :bundles -> "CnfsOkf::Bundle", :concept -> "CnfsOkf::Concept"
      def okf_class_for(name) = "CnfsOkf::#{name.to_s.classify}"
    end
  end
end
