class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string  :name,     null: false
      t.string  :email,    null: false
      t.string  :password_digest
      t.integer :role,     null: false, default: 2
      t.string  :institution
      t.string  :country
      t.text    :bio
      t.text    :links

      t.string    :invitation_token
      t.datetime  :invitation_sent_at
      t.datetime  :invitation_accepted_at

      t.string    :password_reset_token
      t.datetime  :password_reset_sent_at

      t.timestamps
    end

    add_index :users, :email,                unique: true
    add_index :users, :invitation_token,     unique: true, where: "invitation_token IS NOT NULL"
    add_index :users, :password_reset_token, unique: true, where: "password_reset_token IS NOT NULL"
  end
end
