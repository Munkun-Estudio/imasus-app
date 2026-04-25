class AddDisabledFieldsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :disabled_at, :datetime
    add_reference :projects, :disabled_by, foreign_key: { to_table: :users }
  end
end
