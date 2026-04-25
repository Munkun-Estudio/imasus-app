class AddContactEmailToWorkshops < ActiveRecord::Migration[8.1]
  def change
    add_column :workshops, :contact_email, :string
  end
end
