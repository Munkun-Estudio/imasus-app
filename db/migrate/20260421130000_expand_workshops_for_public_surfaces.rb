class ExpandWorkshopsForPublicSurfaces < ActiveRecord::Migration[8.1]
  def up
    add_column :workshops, :title_translations, :jsonb, default: {}, null: false
    add_column :workshops, :description_translations, :jsonb, default: {}, null: false
    add_column :workshops, :partner, :string
    add_column :workshops, :starts_on, :date
    add_column :workshops, :ends_on, :date

    execute <<~SQL.squish
      UPDATE workshops
      SET title_translations = jsonb_build_object('en', title)
      WHERE title IS NOT NULL AND title <> ''
    SQL

    execute <<~SQL.squish
      UPDATE workshops
      SET slug = lower(regexp_replace(title, '[^a-zA-Z0-9]+', '-', 'g'))
      WHERE (slug IS NULL OR slug = '') AND title IS NOT NULL AND title <> ''
    SQL

    change_column_null :workshops, :slug, false
    remove_column :workshops, :title, :string
  end

  def down
    add_column :workshops, :title, :string

    execute <<~SQL.squish
      UPDATE workshops
      SET title = COALESCE(title_translations->>'en', title_translations->>'es', title_translations->>'it', title_translations->>'el')
      WHERE title IS NULL
    SQL

    change_column_null :workshops, :slug, true

    remove_column :workshops, :ends_on, :date
    remove_column :workshops, :starts_on, :date
    remove_column :workshops, :partner, :string
    remove_column :workshops, :description_translations, :jsonb
    remove_column :workshops, :title_translations, :jsonb
  end
end
