class MakePromptsAndGlossaryManifestManaged < ActiveRecord::Migration[8.1]
  def up
    add_catalog_columns(:challenges)
    add_catalog_columns(:glossary_terms)

    execute <<~SQL.squish
      UPDATE challenges
      SET position = CASE
        WHEN code ~* '^C[0-9]+$' THEN substring(code from 2)::integer
        ELSE id
      END
    SQL
    execute "UPDATE glossary_terms SET position = id"

    change_column_null :challenges, :position, false
    change_column_null :glossary_terms, :position, false
    add_index :challenges, [ :published, :position ]
    add_index :glossary_terms, [ :published, :position ]

    remove_index :glossary_terms, name: "index_glossary_terms_on_lower_en_term", if_exists: true

    execute <<~SQL.squish
      DELETE FROM bookmarks legacy
      USING challenges
      WHERE legacy.bookmarkable_type = 'Challenge'
        AND legacy.resource_key = challenges.id::text
        AND EXISTS (
          SELECT 1 FROM bookmarks current
          WHERE current.user_id = legacy.user_id
            AND current.bookmarkable_type = 'Challenge'
            AND LOWER(current.resource_key) = LOWER(challenges.code)
        )
    SQL
    execute <<~SQL.squish
      UPDATE bookmarks
      SET resource_key = challenges.code
      FROM challenges
      WHERE bookmarks.bookmarkable_type = 'Challenge'
        AND bookmarks.resource_key = challenges.id::text
    SQL
    execute <<~SQL.squish
      DELETE FROM bookmarks legacy
      USING glossary_terms
      WHERE legacy.bookmarkable_type = 'GlossaryTerm'
        AND legacy.resource_key = glossary_terms.id::text
        AND EXISTS (
          SELECT 1 FROM bookmarks current
          WHERE current.user_id = legacy.user_id
            AND current.bookmarkable_type = 'GlossaryTerm'
            AND current.resource_key = glossary_terms.slug
        )
    SQL
    execute <<~SQL.squish
      UPDATE bookmarks
      SET resource_key = glossary_terms.slug
      FROM glossary_terms
      WHERE bookmarks.bookmarkable_type = 'GlossaryTerm'
        AND bookmarks.resource_key = glossary_terms.id::text
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM bookmarks current
      USING challenges
      WHERE current.bookmarkable_type = 'Challenge'
        AND LOWER(current.resource_key) = LOWER(challenges.code)
        AND EXISTS (
          SELECT 1 FROM bookmarks legacy
          WHERE legacy.user_id = current.user_id
            AND legacy.bookmarkable_type = 'Challenge'
            AND legacy.resource_key = challenges.id::text
        )
    SQL
    execute <<~SQL.squish
      UPDATE bookmarks
      SET resource_key = challenges.id::text
      FROM challenges
      WHERE bookmarks.bookmarkable_type = 'Challenge'
        AND LOWER(bookmarks.resource_key) = LOWER(challenges.code)
    SQL
    execute <<~SQL.squish
      DELETE FROM bookmarks current
      USING glossary_terms
      WHERE current.bookmarkable_type = 'GlossaryTerm'
        AND current.resource_key = glossary_terms.slug
        AND EXISTS (
          SELECT 1 FROM bookmarks legacy
          WHERE legacy.user_id = current.user_id
            AND legacy.bookmarkable_type = 'GlossaryTerm'
            AND legacy.resource_key = glossary_terms.id::text
        )
    SQL
    execute <<~SQL.squish
      UPDATE bookmarks
      SET resource_key = glossary_terms.id::text
      FROM glossary_terms
      WHERE bookmarks.bookmarkable_type = 'GlossaryTerm'
        AND bookmarks.resource_key = glossary_terms.slug
    SQL

    add_index :glossary_terms,
              "LOWER(term_translations->>'en')",
              unique: true,
              name: "index_glossary_terms_on_lower_en_term"
    remove_index :glossary_terms, [ :published, :position ]
    remove_index :challenges, [ :published, :position ]
    remove_catalog_columns(:glossary_terms)
    remove_catalog_columns(:challenges)
  end

  private

  def add_catalog_columns(table)
    add_column table, :position, :integer
    add_column table, :published, :boolean, null: false, default: true
    add_column table, :managed_by_manifest, :boolean, null: false, default: false
    add_column table, :asset_path, :string
    add_column table, :tags, :jsonb, null: false, default: []
  end

  def remove_catalog_columns(table)
    remove_column table, :tags, if_exists: true
    remove_column table, :asset_path
    remove_column table, :managed_by_manifest
    remove_column table, :published
    remove_column table, :position
  end
end
