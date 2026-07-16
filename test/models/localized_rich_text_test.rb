require "test_helper"

class LocalizedRichTextTest < ActiveSupport::TestCase
  def workshop
    Workshop.create!(
      title_translations: { "en" => "Localized agenda" },
      description_translations: { "en" => "A workshop with localized content." },
      location: "Zaragoza",
      starts_on: Date.new(2026, 7, 16),
      ends_on: Date.new(2026, 7, 16)
    )
  end

  test "stores exact locale content without locale-specific model fields" do
    record = workshop
    record.assign_localized_rich_text(:agenda, :en, "<p>English agenda</p>")
    record.assign_localized_rich_text(:agenda, :es, "<p>Agenda española</p>")
    record.save!

    assert_equal "English agenda", record.reload.agenda_in(:en).body.to_plain_text
    assert_equal "Agenda española", record.agenda_in(:es).body.to_plain_text
    assert_nil record.agenda_in(:it)
  end

  test "falls back deterministically and returns nil when no content exists" do
    record = workshop
    assert_nil record.agenda_for(:it)

    record.assign_localized_rich_text(:agenda, :en, "<p>Fallback agenda</p>")
    record.save!

    assert_equal "Fallback agenda", record.reload.agenda_for(:it).body.to_plain_text
  end

  test "rejects locales outside installation configuration" do
    error = assert_raises(ArgumentError) do
      workshop.assign_localized_rich_text(:agenda, :fr, "<p>Non configuré</p>")
    end

    assert_includes error.message, "Unsupported locale"
  end

  test "removes localized rich text when its parent is destroyed" do
    record = workshop
    record.assign_localized_rich_text(:agenda, :en, "<p>Temporary agenda</p>")
    record.save!

    assert_difference -> { LocalizedRichText.count }, -1 do
      record.destroy!
    end
  end
end
