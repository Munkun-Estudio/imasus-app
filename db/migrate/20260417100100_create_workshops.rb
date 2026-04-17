class CreateWorkshops < ActiveRecord::Migration[8.1]
  def change
    create_table :workshops do |t|
      t.string :title,    null: false
      t.string :location, null: false
      t.string :slug
      t.timestamps
    end

    add_index :workshops, :slug, unique: true

    create_table :workshop_participations do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :workshop, null: false, foreign_key: true
      t.timestamps
    end

    add_index :workshop_participations, [ :user_id, :workshop_id ], unique: true
  end
end
