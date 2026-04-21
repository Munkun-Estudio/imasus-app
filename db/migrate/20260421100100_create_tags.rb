class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.integer :facet, null: false
      t.string  :slug,  null: false
      t.jsonb   :name_translations, null: false, default: {}

      t.timestamps
    end

    add_index :tags, [ :facet, :slug ], unique: true
  end
end
