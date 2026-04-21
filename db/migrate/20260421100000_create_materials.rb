class CreateMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :materials do |t|
      t.string  :slug,                null: false
      t.string  :trade_name,          null: false
      t.string  :supplier_name
      t.string  :supplier_url
      t.string  :material_of_origin
      t.integer :availability_status, null: false
      t.integer :position,            null: false, default: 0

      t.jsonb :description_translations,            null: false, default: {}
      t.jsonb :interesting_properties_translations, null: false, default: {}
      t.jsonb :structure_translations,              null: false, default: {}
      t.jsonb :sensorial_qualities_translations,    null: false, default: {}
      t.jsonb :what_problem_it_solves_translations, null: false, default: {}

      t.timestamps
    end

    add_index :materials, "LOWER(slug)", unique: true, name: "index_materials_on_lower_slug"
    add_index :materials, :availability_status
    add_index :materials, :position
  end
end
