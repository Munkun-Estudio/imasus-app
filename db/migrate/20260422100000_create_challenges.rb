class CreateChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :challenges do |t|
      t.string :code,     null: false
      t.string :category, null: false
      t.jsonb  :question_translations,    null: false, default: {}
      t.jsonb  :description_translations, null: false, default: {}

      t.timestamps
    end

    add_index :challenges, "UPPER(code)", unique: true, name: "index_challenges_on_upper_code"
    add_index :challenges, :category
  end
end
