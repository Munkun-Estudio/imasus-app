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

ActiveRecord::Schema[8.1].define(version: 2026_07_20_100000) do
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

  create_table "bookmarks", force: :cascade do |t|
    t.string "bookmarkable_type", null: false
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.string "resource_key", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "bookmarkable_type", "resource_key"], name: "index_bookmarks_unique_per_user", unique: true
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "challenges", force: :cascade do |t|
    t.string "asset_path"
    t.string "category", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.jsonb "description_translations", default: {}, null: false
    t.boolean "managed_by_manifest", default: false, null: false
    t.integer "position", null: false
    t.boolean "published", default: true, null: false
    t.jsonb "question_translations", default: {}, null: false
    t.jsonb "tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.index "upper((code)::text)", name: "index_challenges_on_upper_code", unique: true
    t.index ["category"], name: "index_challenges_on_category"
    t.index ["published", "position"], name: "index_challenges_on_published_and_position"
  end

  create_table "glossary_terms", force: :cascade do |t|
    t.string "asset_path"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.jsonb "definition_translations", default: {}, null: false
    t.jsonb "examples_translations", default: {}, null: false
    t.boolean "managed_by_manifest", default: false, null: false
    t.integer "position", null: false
    t.boolean "published", default: true, null: false
    t.string "slug", null: false
    t.jsonb "tags", default: [], null: false
    t.jsonb "term_translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_glossary_terms_on_category"
    t.index ["published", "position"], name: "index_glossary_terms_on_published_and_position"
    t.index ["slug"], name: "index_glossary_terms_on_slug", unique: true
  end

  create_table "library_item_assets", force: :cascade do |t|
    t.jsonb "alt_text_translations", default: {}, null: false
    t.jsonb "caption_translations", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "credit"
    t.integer "kind"
    t.bigint "library_item_id", null: false
    t.boolean "managed_by_manifest", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "retired_at"
    t.string "role", null: false
    t.string "source_checksum"
    t.string "source_path"
    t.datetime "updated_at", null: false
    t.index ["library_item_id", "kind", "position"], name: "idx_on_library_item_id_kind_position_f4ea666b5e", unique: true
    t.index ["library_item_id", "kind"], name: "index_material_assets_unique_video_kind", unique: true, where: "(kind = 2)"
    t.index ["library_item_id", "role", "position"], name: "index_library_assets_on_item_role_position", unique: true
    t.index ["library_item_id", "role", "source_path"], name: "index_library_assets_on_manifest_source", unique: true, where: "(source_path IS NOT NULL)"
    t.index ["library_item_id"], name: "index_library_item_assets_on_library_item_id"
    t.index ["retired_at"], name: "index_library_item_assets_on_retired_at"
  end

  create_table "library_item_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "library_item_id", null: false
    t.bigint "library_taxonomy_term_id", null: false
    t.datetime "updated_at", null: false
    t.index ["library_item_id", "library_taxonomy_term_id"], name: "idx_on_library_item_id_library_taxonomy_term_id_7644b478af", unique: true
    t.index ["library_item_id"], name: "index_library_item_taggings_on_library_item_id"
    t.index ["library_taxonomy_term_id"], name: "index_library_item_taggings_on_library_taxonomy_term_id"
  end

  create_table "library_items", force: :cascade do |t|
    t.integer "availability_status"
    t.datetime "created_at", null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.jsonb "description_translations", default: {}, null: false
    t.jsonb "interesting_properties_translations", default: {}, null: false
    t.string "item_type", default: "material", null: false
    t.jsonb "links", default: [], null: false
    t.boolean "managed_by_manifest", default: false, null: false
    t.string "material_of_origin"
    t.integer "position", default: 0, null: false
    t.boolean "published", default: true, null: false
    t.jsonb "sensorial_qualities_translations", default: {}, null: false
    t.string "slug", null: false
    t.jsonb "structure_translations", default: {}, null: false
    t.jsonb "summary_translations", default: {}, null: false
    t.string "supplier_name"
    t.string "supplier_url"
    t.jsonb "title_translations", default: {}, null: false
    t.string "trade_name"
    t.datetime "updated_at", null: false
    t.jsonb "what_problem_it_solves_translations", default: {}, null: false
    t.index "lower((slug)::text)", name: "index_materials_on_lower_slug", unique: true
    t.index ["availability_status"], name: "index_library_items_on_availability_status"
    t.index ["item_type", "published", "position"], name: "index_library_items_for_catalogue"
    t.index ["position"], name: "index_library_items_on_position"
  end

  create_table "library_taxonomy_terms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "facet"
    t.boolean "managed_by_manifest", default: false, null: false
    t.jsonb "name_translations", default: {}, null: false
    t.integer "position", default: 0, null: false
    t.boolean "published", default: true, null: false
    t.string "slug", null: false
    t.string "taxonomy_key", null: false
    t.datetime "updated_at", null: false
    t.index ["facet", "slug"], name: "index_library_taxonomy_terms_on_facet_and_slug", unique: true
    t.index ["taxonomy_key", "position"], name: "index_library_terms_for_taxonomy"
    t.index ["taxonomy_key", "slug"], name: "index_library_terms_on_taxonomy_and_slug", unique: true
  end

  create_table "localized_rich_texts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name", "locale"], name: "index_localized_rich_texts_on_record_field_and_locale", unique: true
    t.index ["record_type", "record_id"], name: "index_localized_rich_texts_on_record"
  end

  create_table "log_entries", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_log_entries_on_author_id"
    t.index ["project_id"], name: "index_log_entries_on_project_id"
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

  create_table "workshop_email_broadcasts", force: :cascade do |t|
    t.string "audience", null: false
    t.text "body_html", null: false
    t.text "body_text", null: false
    t.datetime "created_at", null: false
    t.integer "recipient_count", default: 0, null: false
    t.bigint "sender_id", null: false
    t.datetime "sent_at", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.bigint "workshop_id", null: false
    t.index ["sender_id"], name: "index_workshop_email_broadcasts_on_sender_id"
    t.index ["sent_at"], name: "index_workshop_email_broadcasts_on_sent_at"
    t.index ["workshop_id"], name: "index_workshop_email_broadcasts_on_workshop_id"
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
    t.string "slug", null: false
    t.date "starts_on"
    t.jsonb "title_translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_workshops_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "library_item_assets", "library_items"
  add_foreign_key "library_item_taggings", "library_items"
  add_foreign_key "library_item_taggings", "library_taxonomy_terms"
  add_foreign_key "log_entries", "projects"
  add_foreign_key "log_entries", "users", column: "author_id"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "projects", "challenges"
  add_foreign_key "projects", "users", column: "disabled_by_id"
  add_foreign_key "projects", "workshops"
  add_foreign_key "workshop_email_broadcasts", "users", column: "sender_id"
  add_foreign_key "workshop_email_broadcasts", "workshops"
  add_foreign_key "workshop_participations", "users"
  add_foreign_key "workshop_participations", "workshops"
end
