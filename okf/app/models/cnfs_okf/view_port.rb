module CnfsOkf
  class ViewPort < ApplicationRecord
    include FsNode

    belongs_to :bundle, class_name: "CnfsOkf::Bundle", inverse_of: :view_ports

    validate :path_must_be_directory, unless: ->(record) { record.path.nil? }

    def pathname = bundle.pathname.join(path)

    # Returns an AR::Relation of concepts scoped to this viewport's directory.
    def concepts
      prefix = path.to_s.sub(/^\/+/, "")
      return bundle.concepts if prefix.empty?

      prefix = "#{prefix}/" unless prefix.end_with?("/")
      bundle.concepts.where("path LIKE ?", "#{prefix}%")
    end

    private

    def path_must_be_directory
      return unless pathname.exist?

      errors.add(:path, "'#{pathname}' is not a directory") unless pathname.directory?
    end
  end
end
