class AddPublicationToProjects < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :projects, :slug, :string
    add_column :projects, :publication_updated_at, :datetime

    add_index :projects, :slug, unique: true, where: "slug IS NOT NULL",
              algorithm: :concurrently
  end
end
