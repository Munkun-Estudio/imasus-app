class CreateGlossaryTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :glossary_terms do |t|
      t.string :slug,     null: false
      t.string :category, null: false
      t.jsonb  :term_translations,       null: false, default: {}
      t.jsonb  :definition_translations, null: false, default: {}
      t.jsonb  :examples_translations,   null: false, default: {}

      t.timestamps
    end

    add_index :glossary_terms, :slug, unique: true
    add_index :glossary_terms, :category
    add_index :glossary_terms,
              "LOWER(term_translations->>'en')",
              unique: true,
              name: "index_glossary_terms_on_lower_en_term"
  end
end
