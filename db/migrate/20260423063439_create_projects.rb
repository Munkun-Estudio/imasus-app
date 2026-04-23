class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :workshop,  null: false, foreign_key: true
      t.references :challenge, null: true,  foreign_key: true
      t.string :title,    null: false
      t.text   :description
      t.string :language, null: false
      t.string :status,   null: false, default: "draft"

      t.timestamps
    end
  end
end
