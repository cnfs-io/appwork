class CreateOkfV3Models < ActiveRecord::Migration[8.1]
  def change
    create_table :okf_bundles do |t|
      t.string     :sti_type, null: false        # STI discriminator (RootBundle/Bundle)
      t.references :bundle, foreign_key: { to_table: :okf_bundles }  # parent; null for RootBundle
      t.string     :path, null: false            # absolute (RootBundle) or relative-to-parent
      t.references :owner, polymorphic: true      # singular owner (not enforced yet)
      t.timestamps
    end

    create_table :okf_concepts do |t|
      t.references :bundle, null: false, foreign_key: { to_table: :okf_bundles }
      t.string  :path, null: false                # bundle-relative path of the file
      t.integer :ino                              # inode; null until materialized/synced
      t.string  :content_hash                     # sha256 of file bytes; null pre-parse

      # --- OKF-standard frontmatter (names match the SPEC exactly) ---
      t.string   :type                            # OKF frontmatter type (NOT Rails STI)
      t.string   :title
      t.string   :description
      t.string   :resource                        # canonical URI of the asset
      t.json     :tags, default: []
      t.datetime :timestamp                       # OKF "last meaningful change"

      t.text :custom_frontmatter                  # YAML-serialized Hash of consumer keys

      t.references :owner, polymorphic: true       # singular owner (not enforced yet)
      t.timestamps
    end
  end
end
