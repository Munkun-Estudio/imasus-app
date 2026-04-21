class CreateMaterialTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :material_taggings do |t|
      t.references :material, null: false, foreign_key: true
      t.references :tag,      null: false, foreign_key: true

      t.timestamps
    end

    add_index :material_taggings, [ :material_id, :tag_id ], unique: true
  end
end
