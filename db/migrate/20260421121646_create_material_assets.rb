class CreateMaterialAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :material_assets do |t|
      t.references :material, null: false, foreign_key: true
      t.integer    :kind,     null: false
      t.integer    :position, null: false, default: 0

      t.timestamps
    end

    # Ordering within a material/kind must be unique (for microscopies this is
    # the m1/m2/m3 slot; for macro and video there is only one row at
    # position 0).
    add_index :material_assets, [ :material_id, :kind, :position ], unique: true

    # At most one macro (kind 0) and one video (kind 2) per material.
    add_index :material_assets, [ :material_id, :kind ],
              unique: true,
              where:  "kind IN (0, 2)",
              name:   "index_material_assets_unique_singleton_kinds"
  end
end
