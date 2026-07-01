module CnfsOkf
  class Bundle < ApplicationRecord
    include FsNode
    include FsBundle

    CONCEPT_SEARCH_PATTERN = "**/*.md".freeze

    has_many :concepts, class_name: "CnfsOkf::Concept",
             dependent: :destroy, inverse_of: :bundle
    has_many :view_ports, class_name: "CnfsOkf::ViewPort",
             dependent: :destroy, inverse_of: :bundle

    before_validation :expand_path, prepend: true, unless: ->(record) { record.path.nil? }

    validates :dev, presence: true

    after_create :create_concepts

    def pathname
      return nil unless path

      (@pathname_cache ||= {})[path] ||= Pathname.new(path)
    end

    def ident
      return unless (s = super)

      self.dev = s.dev
    end

    def create_concepts
      concept_paths.each do |rel_path|
        concepts.find_or_create_by(path: rel_path.to_s)
      end
    end

    def concept_paths
      (dir = pathname) ? dir.glob(CONCEPT_SEARCH_PATTERN).map { |p| p.relative_path_from(dir) } : []
    end

    def tree = concept_paths.map(&:dirname).uniq

    def ls(path = "") = view_ports.build(path: path).concepts

    private

    def expand_path
      self.path = Pathname.new(path).expand_path.to_s
    end
  end
end
