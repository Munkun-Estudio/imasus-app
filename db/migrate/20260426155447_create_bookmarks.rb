class CreateBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :bookmarkable_type, null: false
      t.string :resource_key,      null: false
      t.string :label,             null: false
      t.string :url,               null: false

      t.timestamps
    end

    add_index :bookmarks, %i[user_id bookmarkable_type resource_key], unique: true,
                                                                       name: "index_bookmarks_unique_per_user"
  end
end
