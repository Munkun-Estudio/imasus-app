class AllowMultipleMaterialMacroAssets < ActiveRecord::Migration[8.1]
  def up
    remove_index :material_assets, name: "index_material_assets_unique_singleton_kinds"

    add_index :material_assets, [ :material_id, :kind ],
              unique: true,
              where:  "kind = 2",
              name:   "index_material_assets_unique_video_kind"
  end

  def down
    remove_index :material_assets, name: "index_material_assets_unique_video_kind"

    add_index :material_assets, [ :material_id, :kind ],
              unique: true,
              where:  "kind IN (0, 2)",
              name:   "index_material_assets_unique_singleton_kinds"
  end
end
