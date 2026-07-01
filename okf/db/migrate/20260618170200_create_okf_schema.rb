class CreateCnfsOkfV3Models < ActiveRecord::Migration[8.1]
  def change
    create_table :cnfs_okf_bundles do |t|
      t.string     :path, null: false            # absolute path to directory on FS
      t.integer    :ino                          # inode; null until first ident
      t.integer    :dev                          # device id; used to detect cross-fs moves
      t.references :owner, polymorphic: true
      t.timestamps
    end

    create_table :cnfs_okf_concepts do |t|
      t.references :bundle, null: false, foreign_key: { to_table: :cnfs_okf_bundles }
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

      t.index [ :bundle_id, :path ], unique: true
    end

    create_table :cnfs_okf_view_ports do |t|
      t.references :bundle, null: false, foreign_key: { to_table: :cnfs_okf_bundles }
      t.string     :path, null: false, default: ""  # bundle-relative dir path; "" = bundle root
      t.integer    :ino
      t.references :owner, polymorphic: true
      t.timestamps
    end
  end
end
