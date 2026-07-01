module CnfsOkf
  class RootBundle < Bundle
    # A RootBundle is a Bundle with no parent; its `path` is absolute.
    # No behavior to add yet — the STI subclass exists so consumers can say
    # `owns_one_cnfs_okf :root_bundle, class_name: "CnfsOkf::RootBundle"` and so future
    # root-specific behavior has a home. pathname's base case already covers it.
    before_validation :expand_path, unless: ->(record) { record.path.nil? }
    validates :path, presence: true
    validate :path_must_exist, unless: ->(record) { record.path.nil? }

    def content_from(root = "")
      return [] unless (path = pathname)

      root = root.to_s.sub(/^\/+/, "")
      path.glob("#{root}**/*.md").map { |p| p.relative_path_from(path) }
    end

    def create_from(root = "")
      content_from(root).each do |path|
        concepts.create(path: path)
      end
    end

    private

    def expand_path
      self.path = pathname.expand_path.to_s
    end

    def path_must_exist
      errors.add(:path, "'#{pathname}' does not exist") unless pathname.exist?
    end
  end
end
