class AddGenericLibraryAssetMetadata < ActiveRecord::Migration[8.0]
  LEGACY_ROLES = {
    0 => "macro",
    1 => "microscopy",
    2 => "video"
  }.freeze

  def up
    change_column_null :library_item_assets, :kind, true
    change_table :library_item_assets, bulk: true do |table|
      table.string :role
      table.jsonb :alt_text_translations, null: false, default: {}
      table.jsonb :caption_translations, null: false, default: {}
      table.string :credit
      table.string :source_path
      table.string :source_checksum
      table.boolean :managed_by_manifest, null: false, default: false
      table.datetime :retired_at
    end

    cases = LEGACY_ROLES.map { |kind, role| "WHEN #{kind} THEN '#{role}'" }.join(" ")
    execute <<~SQL.squish
      UPDATE library_item_assets
      SET role = CASE kind #{cases} END
    SQL
    change_column_null :library_item_assets, :role, false

    add_index :library_item_assets, %i[library_item_id role position], unique: true,
                                                                       name: "index_library_assets_on_item_role_position"
    add_index :library_item_assets, %i[library_item_id role source_path], unique: true,
                                                                          where: "source_path IS NOT NULL",
                                                                          name: "index_library_assets_on_manifest_source"
    add_index :library_item_assets, :retired_at
  end

  def down
    assert_legacy_rollback_is_safe!
    remove_index :library_item_assets, name: "index_library_assets_on_item_role_position"
    remove_index :library_item_assets, name: "index_library_assets_on_manifest_source"
    remove_index :library_item_assets, :retired_at
    remove_columns :library_item_assets, :role, :alt_text_translations,
                   :caption_translations, :credit, :source_path,
                   :source_checksum, :managed_by_manifest, :retired_at
    change_column_null :library_item_assets, :kind, false
  end

  private

  def assert_legacy_rollback_is_safe!
    predicates = LEGACY_ROLES.map do |kind, role|
      "(kind = #{kind} AND role = '#{role}')"
    end.join(" OR ")
    incompatible = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM library_item_assets
      WHERE kind IS NULL OR NOT (#{predicates})
    SQL
    return if incompatible.zero?

    raise ActiveRecord::IrreversibleMigration,
          "#{incompatible} generic Library assets cannot fit the legacy MaterialAsset roles"
  end
end
