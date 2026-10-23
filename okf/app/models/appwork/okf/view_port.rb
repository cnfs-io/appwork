module Appwork
  module Okf
    class ViewPort < ApplicationRecord
      include FsNode

      belongs_to :bundle, class_name: "Appwork::Okf::Bundle", inverse_of: :view_ports

      # Returns an ActiveRecord_Associations_CollectionProxy scoped to this viewport's directory.
      has_many :concepts,
        ->(vp) { vp.prefix.empty? ? all : where("appwork_okf_concepts.path LIKE ?", "#{vp.prefix}%") },
        through: :bundle,
        source: :concepts

      # Per-instantiation instruction to create the viewport's directory on disk —
      # not persisted state (see plan 007 §1). Defaults off: without it, a viewport
      # over a non-existent directory is invalid, exactly as before.
      attr_accessor :materialize

      # prepend: true is load-bearing. FsNode's before_validation :ident reads stat
      # to set :ino; the directory must exist before that runs or :ino stays nil and
      # the record fails validation anyway. Bundle uses prepend: true on expand_path
      # for the same ordering reason.
      before_validation :materialize_path, prepend: true, if: -> { materialize && path.present? }

      validate :path_must_be_within_bundle, unless: ->(record) { record.path.nil? || record.bundle.nil? }
      validate :path_must_be_directory, unless: ->(record) { record.path.nil? }
      validate :path_must_exist_as_directory, unless: ->(record) { record.path.nil? }

      def prefix
        p = path.to_s.sub(/\A\.\/?/, "").sub(/\A\/+/, "")
        return "" if p.empty?

        ActiveRecord::Base.sanitize_sql_like(p.end_with?("/") ? p : "#{p}/")
      end

      def pathname = bundle.pathname.join(path)

      # Create the viewport's directory (including intermediates). For console use;
      # the `materialize: true` attribute is the supported path since it fires in the
      # correct order within the validation chain.
      def materialize! = pathname.mkpath

      # Returns a list of subdirectories
      def tree = pathname.glob("*/**").map(&:parent).select(&:directory?).map { |p| p.relative_path_from(pathname) }.uniq

      def ls = concepts
      private

      # Guarded by within_bundle? so a `path` escaping the bundle never mkpaths
      # outside it — materialize_path is a before_validation and runs BEFORE
      # path_must_be_within_bundle could reject the record, so the guard has to live
      # here, not in the validation.
      def materialize_path
        return unless within_bundle?

        pathname.mkpath unless pathname.exist?
      end

      # Materialization is bundle-relative; a path like "../../etc" would create
      # directories outside the bundle. This runs regardless of `materialize` since
      # escaping the bundle root is wrong either way. cleanpath is lexical rather
      # than realpath (which requires existence, defeating the purpose when the
      # directory is about to be created) — it does NOT defend against symlinks
      # inside the bundle pointing outward; that is out of scope.
      def path_must_be_within_bundle
        return if within_bundle?

        errors.add(:path, "'#{path}' escapes the bundle root")
      end

      def within_bundle?
        bundle_root = bundle.pathname.cleanpath
        target = pathname.cleanpath
        target == bundle_root || target.to_s.start_with?("#{bundle_root}/")
      end

      def path_must_be_directory
        return unless pathname.exist?

        errors.add(:path, "'#{pathname}' is not a directory") unless pathname.directory?
      end

      # Names the fix. FsNode's path_must_exist also fires for a missing path, but
      # its "ino can't be blank"/"does not exist" messages point nowhere near the
      # cause. A duplicate error on :path is acceptable; a confusing one is not.
      def path_must_exist_as_directory
        return if pathname.exist?

        errors.add(:path, "'#{pathname}' does not exist (pass `materialize: true` to create it)")
      end
    end
  end
end
