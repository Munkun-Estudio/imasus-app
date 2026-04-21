require "test_helper"

class TagTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      facet:             "origin_type",
      slug:              "plants",
      name_translations: { "en" => "Plants" }
    }.merge(overrides)
  end

  # --- Translatable: name reader ---------------------------------------------

  test "name reads from the current locale" do
    tag = Tag.new(name_translations: { "en" => "Leather", "es" => "Cuero" })
    assert_equal "Leather", I18n.with_locale(:en) { tag.name }
    assert_equal "Cuero",   I18n.with_locale(:es) { tag.name }
  end

  test "name falls back to English when the current locale is missing" do
    tag = Tag.new(name_translations: { "en" => "Leather" })
    assert_equal "Leather", I18n.with_locale(:it) { tag.name }
  end

  # --- Validations -----------------------------------------------------------

  test "valid with facet, slug, and a base-locale name" do
    assert Tag.new(valid_attributes).valid?
  end

  test "requires a facet" do
    record = Tag.new(valid_attributes(facet: nil))
    assert_not record.valid?
    assert record.errors[:facet].any?
  end

  test "rejects an unknown facet" do
    assert_raises ArgumentError do
      Tag.new(valid_attributes(facet: "unknown"))
    end
  end

  test "accepts each of the three canonical facets" do
    %w[origin_type textile_imitating application].each_with_index do |facet, i|
      record = Tag.new(valid_attributes(facet: facet, slug: "slug-#{i}"))
      assert record.valid?, "expected '#{facet}' to validate: #{record.errors.full_messages.to_sentence}"
    end
  end

  test "requires a slug" do
    record = Tag.new(valid_attributes(slug: nil))
    assert_not record.valid?
    assert record.errors[:slug].any?
  end

  test "requires a base-locale (English) name" do
    record = Tag.new(valid_attributes(name_translations: { "es" => "Plantas" }))
    assert_not record.valid?
    assert record.errors[:name_translations].any?
  end

  test "slug uniqueness is scoped to facet" do
    Tag.create!(valid_attributes)

    same_facet = Tag.new(valid_attributes)
    assert_not same_facet.valid?
    assert same_facet.errors[:slug].any?

    other_facet = Tag.new(valid_attributes(facet: "application"))
    assert other_facet.valid?, other_facet.errors.full_messages.to_sentence
  end
end
