require "test_helper"
require Rails.root.join("db/migrate/20260716190000_create_localized_rich_texts")

class CreateLocalizedRichTextsTest < ActiveSupport::TestCase
  test "copies legacy agendas for deploy safety and syncs edits back on rollback" do
    workshop = Workshop.create!(
      slug: "legacy-agenda-migration",
      title_translations: { "en" => "Legacy agenda" },
      description_translations: { "en" => "Migration test." },
      location: "Zaragoza",
      starts_on: Date.new(2026, 7, 16),
      ends_on: Date.new(2026, 7, 16)
    )
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("agenda attachment"),
      filename: "agenda.txt",
      content_type: "text/plain"
    )
    body = %(<p>Legacy body</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
    rich_text = ActionText::RichText.create!(
      record: workshop,
      name: "agenda_es",
      body:
    )
    original_id = rich_text.id
    original_body = rich_text.body.to_s

    migration = CreateLocalizedRichTexts.new
    migration.send(:copy_legacy_workshop_agendas)

    localized = LocalizedRichText.find_by!(
      record: workshop,
      name: "agenda",
      locale: "es"
    )
    copy = ActionText::RichText.find_by!(
      record: localized,
      name: "content"
    )
    rich_text.reload
    assert_equal original_id, rich_text.id
    assert_equal "Workshop", rich_text.record_type
    assert_equal workshop.id, rich_text.record_id
    assert_equal "agenda_es", rich_text.name
    assert_equal original_body, rich_text.body.to_s
    assert_not_equal original_id, copy.id
    assert_equal original_body, copy.body.to_s
    assert_equal [ blob.id ], copy.embeds_attachments.map(&:blob_id)

    copy.update!(body: body.sub("Legacy body", "Edited after deploy"))

    migration.send(:restore_legacy_workshop_agendas)

    rich_text.reload
    assert_equal original_id, rich_text.id
    assert_equal "Workshop", rich_text.record_type
    assert_equal workshop.id, rich_text.record_id
    assert_equal "agenda_es", rich_text.name
    assert_includes rich_text.body.to_s, "Edited after deploy"
    assert_equal [ blob.id ], rich_text.embeds_attachments.map(&:blob_id)
    assert_not ActionText::RichText.exists?(copy.id)
  end
end
