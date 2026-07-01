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

ActiveRecord::Schema[8.1].define(version: 2026_06_28_170201) do
  create_table "cnfs_okf_bundles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dev"
    t.integer "ino"
    t.integer "owner_id"
    t.string "owner_type"
    t.string "path", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_cnfs_okf_bundles_on_owner"
  end

  create_table "cnfs_okf_concepts", force: :cascade do |t|
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
    t.index ["bundle_id", "path"], name: "index_cnfs_okf_concepts_on_bundle_id_and_path", unique: true
    t.index ["bundle_id"], name: "index_cnfs_okf_concepts_on_bundle_id"
    t.index ["owner_type", "owner_id"], name: "index_cnfs_okf_concepts_on_owner"
  end

  create_table "cnfs_okf_view_ports", force: :cascade do |t|
    t.integer "bundle_id", null: false
    t.datetime "created_at", null: false
    t.integer "ino"
    t.integer "owner_id"
    t.string "owner_type"
    t.string "path", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["bundle_id"], name: "index_cnfs_okf_view_ports_on_bundle_id"
    t.index ["owner_type", "owner_id"], name: "index_cnfs_okf_view_ports_on_owner"
  end

  create_table "goals", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "strategy_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["strategy_id"], name: "index_goals_on_strategy_id"
  end

  create_table "issues", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "project_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_issues_on_project_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "projects", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "goal_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["goal_id"], name: "index_projects_on_goal_id"
  end

  create_table "strategies", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "organization_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_strategies_on_organization_id"
  end

  add_foreign_key "cnfs_okf_concepts", "cnfs_okf_bundles", column: "bundle_id"
  add_foreign_key "cnfs_okf_view_ports", "cnfs_okf_bundles", column: "bundle_id"
  add_foreign_key "goals", "strategies"
  add_foreign_key "issues", "projects"
  add_foreign_key "projects", "goals"
  add_foreign_key "strategies", "organizations"
end
