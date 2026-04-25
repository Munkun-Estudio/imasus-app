class RemovePartnerFromWorkshops < ActiveRecord::Migration[8.1]
  def change
    remove_column :workshops, :partner, :string
  end
end
