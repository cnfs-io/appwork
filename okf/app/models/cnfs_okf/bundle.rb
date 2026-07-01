module CnfsOkf
  class Bundle < ApplicationRecord
    self.inheritance_column = :sti_type   # STI on `sti_type`, not `type`

    belongs_to :parent, class_name: "CnfsOkf::Bundle",
               foreign_key: :bundle_id, optional: true, inverse_of: :children
    has_many :children, class_name: "CnfsOkf::Bundle",
             foreign_key: :bundle_id, dependent: :destroy, inverse_of: :parent

    has_many :concepts, class_name: "CnfsOkf::Concept",
             dependent: :destroy, inverse_of: :bundle

    belongs_to :owner, polymorphic: true, optional: true

    # Absolute path on disk. RootBundle has no parent → its `path` IS absolute
    # (base case). A nested bundle joins its relative `path` onto its parent's
    # absolute pathname, recursing to the root. One definition handles any depth.
    def pathname
      return nil unless path

      parent ? parent.pathname.join(path) : Pathname.new(path)
    end
  end
end
