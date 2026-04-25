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

ActiveRecord::Schema[8.1].define(version: 2026_04_25_152152) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "challenges", force: :cascade do |t|
    t.string "category", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.jsonb "description_translations", default: {}, null: false
    t.jsonb "question_translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index "upper((code)::text)", name: "index_challenges_on_upper_code", unique: true
    t.index ["category"], name: "index_challenges_on_category"
  end

  create_table "glossary_terms", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.jsonb "definition_translations", default: {}, null: false
    t.jsonb "examples_translations", default: {}, null: false
    t.string "slug", null: false
    t.jsonb "term_translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index "lower((term_translations ->> 'en'::text))", name: "index_glossary_terms_on_lower_en_term", unique: true
    t.index ["category"], name: "index_glossary_terms_on_category"
    t.index ["slug"], name: "index_glossary_terms_on_slug", unique: true
  end

  create_table "log_entries", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_log_entries_on_author_id"
    t.index ["project_id"], name: "index_log_entries_on_project_id"
  end

  create_table "material_assets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kind", null: false
    t.bigint "material_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["material_id", "kind", "position"], name: "index_material_assets_on_material_id_and_kind_and_position", unique: true
    t.index ["material_id", "kind"], name: "index_material_assets_unique_singleton_kinds", unique: true, where: "(kind = ANY (ARRAY[0, 2]))"
    t.index ["material_id"], name: "index_material_assets_on_material_id"
  end

  create_table "material_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "material_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["material_id", "tag_id"], name: "index_material_taggings_on_material_id_and_tag_id", unique: true
    t.index ["material_id"], name: "index_material_taggings_on_material_id"
    t.index ["tag_id"], name: "index_material_taggings_on_tag_id"
  end

  create_table "materials", force: :cascade do |t|
    t.integer "availability_status", null: false
    t.datetime "created_at", null: false
    t.jsonb "description_translations", default: {}, null: false
    t.jsonb "interesting_properties_translations", default: {}, null: false
    t.string "material_of_origin"
    t.integer "position", default: 0, null: false
    t.jsonb "sensorial_qualities_translations", default: {}, null: false
    t.string "slug", null: false
    t.jsonb "structure_translations", default: {}, null: false
    t.string "supplier_name"
    t.string "supplier_url"
    t.string "trade_name", null: false
    t.datetime "updated_at", null: false
    t.jsonb "what_problem_it_solves_translations", default: {}, null: false
    t.index "lower((slug)::text)", name: "index_materials_on_lower_slug", unique: true
    t.index ["availability_status"], name: "index_materials_on_availability_status"
    t.index ["position"], name: "index_materials_on_position"
  end

  create_table "project_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "challenge_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "disabled_at"
    t.bigint "disabled_by_id"
    t.string "language", null: false
    t.datetime "publication_updated_at"
    t.string "slug"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "workshop_id", null: false
    t.index ["challenge_id"], name: "index_projects_on_challenge_id"
    t.index ["disabled_by_id"], name: "index_projects_on_disabled_by_id"
    t.index ["slug"], name: "index_projects_on_slug", unique: true, where: "(slug IS NOT NULL)"
    t.index ["workshop_id"], name: "index_projects_on_workshop_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "facet", null: false
    t.jsonb "name_translations", default: {}, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["facet", "slug"], name: "index_tags_on_facet_and_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "institution"
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_sent_at"
    t.string "invitation_token"
    t.text "links"
    t.string "name", null: false
    t.string "password_digest"
    t.datetime "password_reset_sent_at"
    t.string "password_reset_token"
    t.string "preferred_locale"
    t.integer "role", default: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true, where: "(invitation_token IS NOT NULL)"
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true, where: "(password_reset_token IS NOT NULL)"
  end

  create_table "workshop_participations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workshop_id", null: false
    t.index ["user_id", "workshop_id"], name: "index_workshop_participations_on_user_id_and_workshop_id", unique: true
    t.index ["user_id"], name: "index_workshop_participations_on_user_id"
    t.index ["workshop_id"], name: "index_workshop_participations_on_workshop_id"
  end

  create_table "workshops", force: :cascade do |t|
    t.string "contact_email"
    t.datetime "created_at", null: false
    t.jsonb "description_translations", default: {}, null: false
    t.date "ends_on"
    t.string "location", null: false
    t.string "partner"
    t.string "slug", null: false
    t.date "starts_on"
    t.jsonb "title_translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_workshops_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "log_entries", "projects"
  add_foreign_key "log_entries", "users", column: "author_id"
  add_foreign_key "material_assets", "materials"
  add_foreign_key "material_taggings", "materials"
  add_foreign_key "material_taggings", "tags"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "projects", "challenges"
  add_foreign_key "projects", "users", column: "disabled_by_id"
  add_foreign_key "projects", "workshops"
  add_foreign_key "workshop_participations", "users"
  add_foreign_key "workshop_participations", "workshops"
end
