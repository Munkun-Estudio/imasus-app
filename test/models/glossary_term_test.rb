require "test_helper"

class GlossaryTermTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      term_translations:       { "en" => "Framework" },
      definition_translations: { "en" => "A shared structure that guides how something is built or understood." },
      examples_translations:   { "en" => [ "Imagineering framework", "Design framework" ] },
      category:                "methodology"
    }.merge(overrides)
  end

  # --- Translatable: readers -------------------------------------------------

  test "term reads from the current locale" do
    term = GlossaryTerm.new(term_translations: { "en" => "Framework", "es" => "Marco" })
    assert_equal "Framework", I18n.with_locale(:en) { term.term }
    assert_equal "Marco",     I18n.with_locale(:es) { term.term }
  end

  test "term falls back to the default (en) locale when current is missing" do
    term = GlossaryTerm.new(term_translations: { "en" => "Framework" })
    assert_equal "Framework", I18n.with_locale(:it) { term.term }
  end

  test "term returns nil when neither current nor default is present" do
    term = GlossaryTerm.new(term_translations: { "es" => "Marco" })
    assert_nil I18n.with_locale(:it) { term.term }
  end

  test "definition follows the same read-and-fallback pattern" do
    term = GlossaryTerm.new(definition_translations: { "en" => "Base", "es" => "Base es" })
    assert_equal "Base es", I18n.with_locale(:es) { term.definition }
    assert_equal "Base",    I18n.with_locale(:it) { term.definition }
  end

  test "examples returns the array stored for the current locale" do
    term = GlossaryTerm.new(examples_translations: { "en" => [ "a", "b" ], "es" => [ "c" ] })
    assert_equal [ "a", "b" ], I18n.with_locale(:en) { term.examples }
    assert_equal [ "c" ],      I18n.with_locale(:es) { term.examples }
  end

  test "term_in returns the exact locale value without fallback" do
    term = GlossaryTerm.new(term_translations: { "en" => "Framework" })
    assert_equal "Framework", term.term_in(:en)
    assert_nil                term.term_in(:es)
  end

  # --- Translatable: writers -------------------------------------------------

  test "term= writes to the current locale slot" do
    term = GlossaryTerm.new
    I18n.with_locale(:es) { term.term = "Marco" }
    assert_equal({ "es" => "Marco" }, term.term_translations)
  end

  test "term= preserves other-locale values" do
    term = GlossaryTerm.new(term_translations: { "en" => "Framework" })
    I18n.with_locale(:es) { term.term = "Marco" }
    assert_equal({ "en" => "Framework", "es" => "Marco" }, term.term_translations)
  end

  # --- Validations -----------------------------------------------------------

  test "valid with base-locale term, definition, and category" do
    assert GlossaryTerm.new(valid_attributes).valid?
  end

  test "requires an English (base-locale) term" do
    record = GlossaryTerm.new(valid_attributes(term_translations: { "es" => "Marco" }))
    assert_not record.valid?
    assert record.errors[:term_translations].any?
  end

  test "requires an English (base-locale) definition" do
    record = GlossaryTerm.new(valid_attributes(definition_translations: { "es" => "Definición" }))
    assert_not record.valid?
    assert record.errors[:definition_translations].any?
  end

  test "requires a category" do
    record = GlossaryTerm.new(valid_attributes(category: nil))
    assert_not record.valid?
    assert record.errors[:category].any?
  end

  test "rejects an unknown category" do
    record = GlossaryTerm.new(valid_attributes(category: "unknown"))
    assert_not record.valid?
    assert record.errors[:category].any?
  end

  test "accepts each of the four canonical categories" do
    %w[methodology application industry science].each_with_index do |category, i|
      record = GlossaryTerm.new(valid_attributes(
        category: category,
        term_translations: { "en" => "Category term #{i}" }
      ))
      assert record.valid?, "expected '#{category}' to validate: #{record.errors.full_messages.to_sentence}"
    end
  end

  test "enforces case-insensitive uniqueness on the base-locale term" do
    GlossaryTerm.create!(valid_attributes)
    dup = GlossaryTerm.new(valid_attributes(term_translations: { "en" => "FRAMEWORK" }))
    assert_not dup.valid?
    assert dup.errors[:term_translations].any?
  end

  # --- Slug -------------------------------------------------------------------

  test "generates a URL-safe slug from the base-locale term on create" do
    term = GlossaryTerm.create!(valid_attributes)
    assert_equal "framework", term.slug
  end

  test "slug is not regenerated when the term is updated" do
    term = GlossaryTerm.create!(valid_attributes)
    original = term.slug
    term.update!(term_translations: term.term_translations.merge("en" => "Framework (renamed)"))
    assert_equal original, term.slug
  end

  test "to_param returns the slug for URL generation" do
    term = GlossaryTerm.create!(valid_attributes)
    assert_equal term.slug, term.to_param
  end

  test "slug is URL-safe for terms with spaces and punctuation" do
    term = GlossaryTerm.create!(valid_attributes(term_translations: { "en" => "Creative Tension Engine!" }))
    assert_equal "creative-tension-engine", term.slug
  end

  test "slug uniqueness is enforced" do
    GlossaryTerm.create!(valid_attributes)
    dup = GlossaryTerm.new(valid_attributes(
      term_translations: { "en" => "Framework " }, # trailing space same slug, different term-ish
      definition_translations: { "en" => "Dup" }
    ))
    assert_not dup.valid?
  end
end
