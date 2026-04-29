class CreateWorkshopEmailBroadcasts < ActiveRecord::Migration[8.1]
  def change
    create_table :workshop_email_broadcasts do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :workshop, null: false, foreign_key: true
      t.string :audience, null: false
      t.string :subject, null: false
      t.text :body_html, null: false
      t.text :body_text, null: false
      t.integer :recipient_count, null: false, default: 0
      t.datetime :sent_at, null: false

      t.timestamps
    end

    add_index :workshop_email_broadcasts, :sent_at
  end
end
