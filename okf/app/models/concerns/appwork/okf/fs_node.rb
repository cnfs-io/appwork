module Appwork
  module Okf
    module FsNode
      extend ActiveSupport::Concern

      included do
        belongs_to :owner, polymorphic: true, optional: true

        before_validation :ident, unless: ->(record) { record.path.nil? }

        validates :ino, presence: true
        validates :path, presence: true
        validate :path_must_exist, unless: ->(record) { record.path.nil? }
      end

      def path_must_exist
        errors.add(:path, "'#{pathname}' does not exist") unless pathname.exist?
      end

      # Sets ino from stat and returns the stat object so subclasses can use it
      # without a second stat call. Returns nil if the path does not exist.
      def ident
        return unless (file = pathname) && file.exist?

        file.stat.tap { |s| self.ino = s.ino }
      end
    end
  end
end
