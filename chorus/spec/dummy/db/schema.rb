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

ActiveRecord::Schema[8.1].define(version: 2026_07_16_120001) do
  create_table "chorus_agent_adapters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["type"], name: "index_chorus_agent_adapters_on_type"
  end

  create_table "chorus_agent_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "chorus_agents", force: :cascade do |t|
    t.integer "agent_adapter_id"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_adapter_id"], name: "index_chorus_agents_on_agent_adapter_id"
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

  create_table "chorus_catalog_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "install_count"
    t.json "repo_topics"
    t.string "resource", null: false
    t.string "skill_name"
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["resource", "skill_name"], name: "index_chorus_catalog_skills_on_resource_and_skill_name", unique: true
  end

  create_table "chorus_curations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "reputation"
    t.string "resource", null: false
    t.string "skill_name"
    t.datetime "updated_at", null: false
    t.index ["resource", "skill_name"], name: "index_chorus_curations_on_resource_and_skill_name", unique: true
  end

  create_table "chorus_external_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "settings"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["type", "name"], name: "index_chorus_external_accounts_on_type_and_name", unique: true
  end

  create_table "chorus_results", force: :cascade do |t|
    t.boolean "agents_live"
    t.integer "artifact_id"
    t.datetime "created_at", null: false
    t.json "messages", default: {}
    t.json "recorded_argv", default: []
    t.boolean "skills_live"
    t.boolean "success"
    t.datetime "updated_at", null: false
    t.integer "workspace_id"
    t.index ["artifact_id"], name: "index_chorus_results_on_artifact_id"
    t.index ["workspace_id"], name: "index_chorus_results_on_workspace_id"
  end

  create_table "chorus_skill_categorizations", force: :cascade do |t|
    t.integer "catalog_skill_id", null: false
    t.datetime "created_at", null: false
    t.integer "taxonomy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_skill_id", "taxonomy_id"], name: "idx_on_catalog_skill_id_taxonomy_id_7270b7b472", unique: true
    t.index ["catalog_skill_id"], name: "index_chorus_skill_categorizations_on_catalog_skill_id"
    t.index ["taxonomy_id"], name: "index_chorus_skill_categorizations_on_taxonomy_id"
  end

  create_table "chorus_skill_requirements", force: :cascade do |t|
    t.integer "agent_role_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["agent_role_id", "name"], name: "index_chorus_skill_requirements_on_agent_role_id_and_name", unique: true
    t.index ["agent_role_id"], name: "index_chorus_skill_requirements_on_agent_role_id"
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

  create_table "chorus_taxonomies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "parent_id"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_chorus_taxonomies_on_parent_id"
    t.index ["slug"], name: "index_chorus_taxonomies_on_slug", unique: true
  end

  create_table "chorus_workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "workable_id"
    t.string "workable_type"
    t.index ["workable_type", "workable_id"], name: "index_chorus_workspaces_on_workable"
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

  create_table "workable_dummies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "chorus_agents", "chorus_agent_adapters", column: "agent_adapter_id"
  add_foreign_key "chorus_artifacts", "chorus_workspaces", column: "workspace_id"
  add_foreign_key "chorus_results", "chorus_artifacts", column: "artifact_id"
  add_foreign_key "chorus_results", "chorus_workspaces", column: "workspace_id"
  add_foreign_key "chorus_skill_categorizations", "chorus_catalog_skills", column: "catalog_skill_id"
  add_foreign_key "chorus_skill_categorizations", "chorus_taxonomies", column: "taxonomy_id"
  add_foreign_key "chorus_skill_requirements", "chorus_agent_roles", column: "agent_role_id"
  add_foreign_key "chorus_taxonomies", "chorus_taxonomies", column: "parent_id"
  add_foreign_key "cnfs_okf_concepts", "cnfs_okf_bundles", column: "bundle_id"
  add_foreign_key "cnfs_okf_view_ports", "cnfs_okf_bundles", column: "bundle_id"
end
