module CnfsOkf
  class RootBundle < Bundle
    include PathValidatable

    before_validation :expand_path, unless: ->(record) { record.path.nil? }

    after_create :create_concepts

    def concept_paths
      return [] unless (dir = pathname)

      dir.glob("**/*.md").map { |p| p.relative_path_from(dir) }
    end

    # TODO: implement
    # def sync_concepts
    #   create and either soft or hard delete concepts where !path.exist?
    #   maybe a warning if the polymorphic owner is set, otherwise safe to delete
    #   validate existing concept's ino matches stat.ino
    # end

    def create_concepts
      concept_paths.each do |rel_path|
        concepts.find_or_create_by(path: rel_path.to_s)
      end
    end

    private

    def expand_path
      self.path = pathname.expand_path.to_s
    end

    # def content_from(root = "")
    #   return [] unless (path = pathname)

    #   root = root.to_s.sub(/^\/+/, "")
    #   path.glob("#{root}**/*.md").map { |p| p.relative_path_from(path) }
    # end

    # def create_from(root = "")
    #   content_from(root).each do |path|
    #     concepts.create(path: path)
    #   end
    # end

  end
end
