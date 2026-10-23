# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_16_000003) do
  create_table "appwork_gtd_actions", force: :cascade do |t|
    t.integer "context_id"
    t.datetime "created_at", null: false
    t.integer "project_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["context_id"], name: "index_appwork_gtd_actions_on_context_id"
    t.index ["project_id"], name: "index_appwork_gtd_actions_on_project_id"
  end

  create_table "appwork_gtd_contexts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "appwork_gtd_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "appwork_okf_bundles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dev"
    t.integer "ino"
    t.integer "owner_id"
    t.string "owner_type"
    t.string "path", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_appwork_okf_bundles_on_owner"
  end

  create_table "appwork_okf_concepts", force: :cascade do |t|
    t.integer "bundle_id", null: false
    t.string "content_hash"
    t.datetime "created_at", null: false
    t.text "custom_frontmatter"
    t.string "description"
    t.integer "ino"
    t.integer "owner_id"
    t.string "owner_type"
    t.string "path", null: false
    t.string "resource"
    t.json "tags", default: []
    t.datetime "timestamp"
    t.string "title"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["bundle_id", "path"], name: "index_appwork_okf_concepts_on_bundle_id_and_path", unique: true
    t.index ["bundle_id"], name: "index_appwork_okf_concepts_on_bundle_id"
    t.index ["owner_type", "owner_id"], name: "index_appwork_okf_concepts_on_owner"
  end

  create_table "appwork_okf_view_ports", force: :cascade do |t|
    t.integer "bundle_id", null: false
    t.datetime "created_at", null: false
    t.integer "ino"
    t.integer "owner_id"
    t.string "owner_type"
    t.string "path", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["bundle_id"], name: "index_appwork_okf_view_ports_on_bundle_id"
    t.index ["owner_type", "owner_id"], name: "index_appwork_okf_view_ports_on_owner"
  end

  add_foreign_key "appwork_gtd_actions", "appwork_gtd_contexts", column: "context_id"
  add_foreign_key "appwork_gtd_actions", "appwork_gtd_projects", column: "project_id"
  add_foreign_key "appwork_okf_concepts", "appwork_okf_bundles", column: "bundle_id"
  add_foreign_key "appwork_okf_view_ports", "appwork_okf_bundles", column: "bundle_id"
end
