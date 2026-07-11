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

ActiveRecord::Schema[8.1].define(version: 2026_06_20_120001) do
  create_table "chorus_agent_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "chorus_agents", force: :cascade do |t|
    t.integer "agent_id"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "role_id"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_chorus_agents_on_agent_id"
    t.index ["role_id"], name: "index_chorus_agents_on_role_id"
  end

  create_table "chorus_artifacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "kind"
    t.string "locator"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["workspace_id"], name: "index_chorus_artifacts_on_workspace_id"
  end

  create_table "chorus_external_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "settings"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["type", "name"], name: "index_chorus_external_accounts_on_type_and_name", unique: true
  end

  create_table "chorus_goals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "status"
    t.integer "strategy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["strategy_id"], name: "index_chorus_goals_on_strategy_id"
  end

  create_table "chorus_issues", force: :cascade do |t|
    t.integer "agent_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "position"
    t.integer "project_id", null: false
    t.string "status"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_chorus_issues_on_agent_id"
    t.index ["project_id"], name: "index_chorus_issues_on_project_id"
  end

  create_table "chorus_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "goal_id", null: false
    t.string "name", null: false
    t.string "slug"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["goal_id"], name: "index_chorus_projects_on_goal_id"
  end

  create_table "chorus_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "chorus_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "chorus_sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "digest"
    t.string "path"
    t.string "ref"
    t.string "resource", null: false
    t.text "settings"
    t.datetime "synced_at"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["type"], name: "index_chorus_sources_on_type"
  end

  create_table "chorus_strategies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "chorus_workspaces", force: :cascade do |t|
    t.integer "active_project_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["active_project_id"], name: "index_chorus_workspaces_on_active_project_id"
  end

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

  add_foreign_key "chorus_agents", "agent_profiles", column: "agent_id"
  add_foreign_key "chorus_agents", "chorus_roles", column: "role_id"
  add_foreign_key "chorus_artifacts", "chorus_workspaces", column: "workspace_id"
  add_foreign_key "chorus_goals", "chorus_strategies", column: "strategy_id"
  add_foreign_key "chorus_issues", "chorus_agents", column: "agent_id"
  add_foreign_key "chorus_issues", "chorus_projects", column: "project_id"
  add_foreign_key "chorus_projects", "chorus_goals", column: "goal_id"
  add_foreign_key "chorus_workspaces", "chorus_projects", column: "active_project_id"
  add_foreign_key "cnfs_okf_concepts", "cnfs_okf_bundles", column: "bundle_id"
  add_foreign_key "cnfs_okf_view_ports", "cnfs_okf_bundles", column: "bundle_id"
end
