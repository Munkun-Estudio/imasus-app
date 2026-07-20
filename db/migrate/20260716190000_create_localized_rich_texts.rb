class CreateLocalizedRichTexts < ActiveRecord::Migration[8.1]
  LEGACY_AGENDA_NAMES = %w[agenda_en agenda_es agenda_it agenda_el].freeze

  class MigrationLocalizedRichText < ActiveRecord::Base
    self.table_name = "localized_rich_texts"
  end

  class MigrationActionTextRichText < ActiveRecord::Base
    self.table_name = "action_text_rich_texts"
  end

  class MigrationActiveStorageAttachment < ActiveRecord::Base
    self.table_name = "active_storage_attachments"
  end

  def up
    remove_index :glossary_terms,
                 name: "index_glossary_terms_on_lower_en_term",
                 if_exists: true

    create_table :localized_rich_texts do |t|
      t.references :record, polymorphic: true, null: false
      t.string :name, null: false
      t.string :locale, null: false
      t.timestamps
    end

    add_index :localized_rich_texts,
              %i[record_type record_id name locale],
              unique: true,
              name: "index_localized_rich_texts_on_record_field_and_locale"

    copy_legacy_workshop_agendas
  end

  def down
    restore_legacy_workshop_agendas
    drop_table :localized_rich_texts

    add_index :glossary_terms,
              "LOWER(term_translations->>'en')",
              unique: true,
              if_not_exists: true,
              name: "index_glossary_terms_on_lower_en_term"
  end

  private

  def copy_legacy_workshop_agendas
    MigrationActionTextRichText
      .where(record_type: "Workshop", name: LEGACY_AGENDA_NAMES)
      .find_each do |legacy|
        locale = legacy.name.delete_prefix("agenda_")
        localized = MigrationLocalizedRichText.create!(
          record_type: "Workshop",
          record_id: legacy.record_id,
          name: "agenda",
          locale:
        )
        copy = MigrationActionTextRichText.create!(
          record_type: "LocalizedRichText",
          record_id: localized.id,
          name: "content",
          body: legacy.body,
          created_at: legacy.created_at,
          updated_at: legacy.updated_at
        )
        copy_attachments(from: legacy, to: copy)
      end
  end

  def restore_legacy_workshop_agendas
    MigrationLocalizedRichText.where(record_type: "Workshop", name: "agenda").find_each do |localized|
      copy = MigrationActionTextRichText.find_by(
        record_type: "LocalizedRichText",
        record_id: localized.id,
        name: "content"
      )
      next unless copy

      legacy = MigrationActionTextRichText.find_by(
        record_type: "Workshop",
        record_id: localized.record_id,
        name: "agenda_#{localized.locale}"
      )

      if legacy
        legacy.update!(body: copy.body, updated_at: copy.updated_at)
        replace_attachments(from: copy, to: legacy)
        delete_rich_text(copy)
      else
        copy.update!(
          record_type: "Workshop",
          record_id: localized.record_id,
          name: "agenda_#{localized.locale}"
        )
      end
    end
  end

  def replace_attachments(from:, to:)
    attachment_scope(to).delete_all
    copy_attachments(from:, to:)
  end

  def copy_attachments(from:, to:)
    attachment_scope(from).find_each do |attachment|
      MigrationActiveStorageAttachment.create!(
        name: attachment.name,
        record_type: "ActionText::RichText",
        record_id: to.id,
        blob_id: attachment.blob_id,
        created_at: attachment.created_at
      )
    end
  end

  def delete_rich_text(rich_text)
    attachment_scope(rich_text).delete_all
    rich_text.delete
  end

  def attachment_scope(rich_text)
    MigrationActiveStorageAttachment.where(
      record_type: "ActionText::RichText",
      record_id: rich_text.id
    )
  end
end
