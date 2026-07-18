class GeneralizeLibrarySchema < ActiveRecord::Migration[8.0]
  LEGACY_TAXONOMIES = {
    0 => "origin_type",
    1 => "textile_imitating",
    2 => "application"
  }.freeze

  def up
    rename_legacy_tables
    add_library_item_contract
    add_taxonomy_contract
    rename_join_columns
    backfill_library_items
    backfill_taxonomies
    migrate_bookmarks_to_stable_identity
    copy_asset_attachments("MaterialAsset", "LibraryItemAsset")
    add_library_indexes
    create_legacy_views
  end

  def down
    assert_legacy_rollback_is_safe!
    drop_legacy_views
    restore_legacy_material_columns
    restore_legacy_taxonomy_columns
    migrate_bookmarks_to_legacy_identity
    copy_asset_attachments("LibraryItemAsset", "MaterialAsset")
    delete_asset_attachments("LibraryItemAsset")
    remove_library_indexes
    remove_taxonomy_contract
    remove_library_item_contract
    rename_join_columns_back
    rename_generic_tables_back
  end

  private

  def rename_legacy_tables
    rename_table :materials, :library_items
    rename_table :tags, :library_taxonomy_terms
    rename_table :material_taggings, :library_item_taggings
    rename_table :material_assets, :library_item_assets
  end

  def add_library_item_contract
    change_column_null :library_items, :trade_name, true
    change_column_null :library_items, :availability_status, true
    change_table :library_items, bulk: true do |table|
      table.string :item_type, null: false, default: "material"
      table.jsonb :title_translations, null: false, default: {}
      table.jsonb :summary_translations, null: false, default: {}
      table.jsonb :custom_fields, null: false, default: {}
      table.jsonb :links, null: false, default: []
      table.boolean :published, null: false, default: true
      table.boolean :managed_by_manifest, null: false, default: false
    end
  end

  def add_taxonomy_contract
    change_column_null :library_taxonomy_terms, :facet, true
    change_table :library_taxonomy_terms, bulk: true do |table|
      table.string :taxonomy_key
      table.integer :position, null: false, default: 0
      table.boolean :published, null: false, default: true
      table.boolean :managed_by_manifest, null: false, default: false
    end
  end

  def rename_join_columns
    rename_column :library_item_taggings, :material_id, :library_item_id
    rename_column :library_item_taggings, :tag_id, :library_taxonomy_term_id
    rename_column :library_item_assets, :material_id, :library_item_id
  end

  def backfill_library_items
    execute <<~SQL.squish
      UPDATE library_items
      SET title_translations = jsonb_build_object('en', trade_name),
          summary_translations = description_translations,
          custom_fields = jsonb_strip_nulls(jsonb_build_object(
            'supplier_name', supplier_name,
            'supplier_url', REPLACE(supplier_url, CHR(92), ''),
            'material_of_origin', material_of_origin,
            'availability_status', CASE availability_status
              WHEN 0 THEN 'commercial'
              WHEN 1 THEN 'in_development'
              WHEN 2 THEN 'research_only'
            END,
            'interesting_properties', interesting_properties_translations,
            'structure', structure_translations,
            'sensorial_qualities', sensorial_qualities_translations,
            'what_problem_it_solves', what_problem_it_solves_translations
          )),
          links = CASE
            WHEN NULLIF(BTRIM(supplier_url), '') IS NULL THEN '[]'::jsonb
            ELSE jsonb_build_array(jsonb_build_object(
              'label', COALESCE(NULLIF(BTRIM(supplier_name), ''), trade_name),
              'url', REPLACE(supplier_url, CHR(92), '')
            ))
          END,
          supplier_url = REPLACE(supplier_url, CHR(92), ''),
          managed_by_manifest = TRUE
    SQL
  end

  def backfill_taxonomies
    cases = LEGACY_TAXONOMIES.map { |facet, key| "WHEN #{facet} THEN '#{key}'" }.join(" ")
    execute <<~SQL.squish
      UPDATE library_taxonomy_terms
      SET taxonomy_key = CASE facet #{cases} END,
          position = id,
          managed_by_manifest = TRUE
    SQL
    change_column_null :library_taxonomy_terms, :taxonomy_key, false
    change_column_null :library_taxonomy_terms, :position, false
  end

  def migrate_bookmarks_to_stable_identity
    execute <<~SQL.squish
      DELETE FROM bookmarks legacy
      USING library_items item, bookmarks canonical
      WHERE legacy.bookmarkable_type = 'Material'
        AND (
          (legacy.resource_key ~ '^[0-9]+$' AND item.id = legacy.resource_key::bigint)
          OR item.slug = legacy.resource_key
        )
        AND canonical.user_id = legacy.user_id
        AND canonical.bookmarkable_type = 'LibraryItem'
        AND canonical.resource_key = item.slug
    SQL
    execute <<~SQL.squish
      DELETE FROM bookmarks duplicate
      USING bookmarks keeper, library_items item
      WHERE duplicate.bookmarkable_type = 'Material'
        AND keeper.bookmarkable_type = 'Material'
        AND duplicate.user_id = keeper.user_id
        AND duplicate.id > keeper.id
        AND duplicate.resource_key IN (item.id::text, item.slug)
        AND keeper.resource_key IN (item.id::text, item.slug)
    SQL
    execute <<~SQL.squish
      UPDATE bookmarks bookmark
      SET bookmarkable_type = 'LibraryItem', resource_key = item.slug
      FROM library_items item
      WHERE bookmark.bookmarkable_type = 'Material'
        AND (
          (bookmark.resource_key ~ '^[0-9]+$' AND item.id = bookmark.resource_key::bigint)
          OR item.slug = bookmark.resource_key
        )
    SQL
  end

  def migrate_bookmarks_to_legacy_identity
    execute <<~SQL.squish
      DELETE FROM bookmarks generic
      USING library_items item, bookmarks legacy
      WHERE generic.bookmarkable_type = 'LibraryItem'
        AND item.slug = generic.resource_key
        AND legacy.user_id = generic.user_id
        AND legacy.bookmarkable_type = 'Material'
        AND legacy.resource_key = item.id::text
    SQL
    execute <<~SQL.squish
      UPDATE bookmarks bookmark
      SET bookmarkable_type = 'Material', resource_key = item.id::text
      FROM library_items item
      WHERE bookmark.bookmarkable_type = 'LibraryItem'
        AND item.slug = bookmark.resource_key
    SQL
  end

  def copy_asset_attachments(from_type, to_type)
    execute <<~SQL.squish
      INSERT INTO active_storage_attachments
        (name, record_type, record_id, blob_id, created_at)
      SELECT source.name, '#{to_type}', source.record_id, source.blob_id, source.created_at
      FROM active_storage_attachments source
      WHERE source.record_type = '#{from_type}'
        AND NOT EXISTS (
          SELECT 1 FROM active_storage_attachments target
          WHERE target.name = source.name
            AND target.record_type = '#{to_type}'
            AND target.record_id = source.record_id
            AND target.blob_id = source.blob_id
        )
    SQL
  end

  def delete_asset_attachments(record_type)
    execute "DELETE FROM active_storage_attachments WHERE record_type = '#{record_type}'"
  end

  def add_library_indexes
    add_index :library_items, %i[item_type published position], name: "index_library_items_for_catalogue"
    add_index :library_taxonomy_terms, %i[taxonomy_key position], name: "index_library_terms_for_taxonomy"
    add_index :library_taxonomy_terms, %i[taxonomy_key slug], unique: true,
                                                            name: "index_library_terms_on_taxonomy_and_slug"
  end

  def remove_library_indexes
    remove_index :library_items, name: "index_library_items_for_catalogue"
    remove_index :library_taxonomy_terms, name: "index_library_terms_for_taxonomy"
    remove_index :library_taxonomy_terms, name: "index_library_terms_on_taxonomy_and_slug"
  end

  def create_legacy_views
    execute "CREATE VIEW materials AS SELECT * FROM library_items"
    execute "CREATE VIEW tags AS SELECT * FROM library_taxonomy_terms"
    execute <<~SQL.squish
      CREATE VIEW material_taggings AS
      SELECT id, library_item_id AS material_id,
             library_taxonomy_term_id AS tag_id, created_at, updated_at
      FROM library_item_taggings
    SQL
    execute <<~SQL.squish
      CREATE VIEW material_assets AS
      SELECT id, library_item_id AS material_id, kind, position, created_at, updated_at
      FROM library_item_assets
    SQL
  end

  def drop_legacy_views
    %w[material_assets material_taggings tags materials].each do |view|
      execute "DROP VIEW IF EXISTS #{view}"
    end
  end

  def restore_legacy_material_columns
    execute <<~SQL.squish
      UPDATE library_items
      SET trade_name = COALESCE(NULLIF(title_translations->>'en', ''), trade_name),
          description_translations = summary_translations,
          supplier_name = custom_fields->>'supplier_name',
          supplier_url = custom_fields->>'supplier_url',
          material_of_origin = custom_fields->>'material_of_origin',
          availability_status = CASE custom_fields->>'availability_status'
            WHEN 'commercial' THEN 0
            WHEN 'in_development' THEN 1
            WHEN 'research_only' THEN 2
            ELSE availability_status
          END,
          interesting_properties_translations = COALESCE(custom_fields->'interesting_properties', '{}'::jsonb),
          structure_translations = COALESCE(custom_fields->'structure', '{}'::jsonb),
          sensorial_qualities_translations = COALESCE(custom_fields->'sensorial_qualities', '{}'::jsonb),
          what_problem_it_solves_translations = COALESCE(custom_fields->'what_problem_it_solves', '{}'::jsonb)
    SQL
  end

  def restore_legacy_taxonomy_columns
    cases = LEGACY_TAXONOMIES.map { |facet, key| "WHEN '#{key}' THEN #{facet}" }.join(" ")
    execute <<~SQL.squish
      UPDATE library_taxonomy_terms
      SET facet = CASE taxonomy_key #{cases} END
    SQL
  end

  def remove_library_item_contract
    remove_columns :library_items, :item_type, :title_translations, :summary_translations,
                   :custom_fields, :links, :published, :managed_by_manifest
    change_column_null :library_items, :trade_name, false
    change_column_null :library_items, :availability_status, false
  end

  def remove_taxonomy_contract
    remove_columns :library_taxonomy_terms, :taxonomy_key, :position, :published,
                   :managed_by_manifest
    change_column_null :library_taxonomy_terms, :facet, false
  end

  def rename_join_columns_back
    rename_column :library_item_taggings, :library_item_id, :material_id
    rename_column :library_item_taggings, :library_taxonomy_term_id, :tag_id
    rename_column :library_item_assets, :library_item_id, :material_id
  end

  def rename_generic_tables_back
    rename_table :library_item_assets, :material_assets
    rename_table :library_item_taggings, :material_taggings
    rename_table :library_taxonomy_terms, :tags
    rename_table :library_items, :materials
  end

  def assert_legacy_rollback_is_safe!
    non_materials = select_value("SELECT COUNT(*) FROM library_items WHERE item_type <> 'material'").to_i
    unknown_taxonomies = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM library_taxonomy_terms
      WHERE taxonomy_key NOT IN ('origin_type', 'textile_imitating', 'application')
    SQL
    return if non_materials.zero? && unknown_taxonomies.zero?

    raise ActiveRecord::IrreversibleMigration,
          "Generic library data cannot fit the legacy Materials schema " \
          "(#{non_materials} non-material items, #{unknown_taxonomies} non-material terms)"
  end
end
