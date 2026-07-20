require "test_helper"

class TrainingModule::LoaderTest < ActiveSupport::TestCase
  setup do
    @loader = TrainingModule::Loader.new
  end

  test "all returns four modules" do
    modules = @loader.all
    assert_equal 4, modules.size
  end

  test "all returns module slugs matching content directories" do
    slugs = @loader.all.map(&:slug).sort
    expected = %w[design-for-longevity design-for-modularity design-for-recyclability zero-waste-design]
    assert_equal expected, slugs
  end

  test "all follows manifest order and localized metadata" do
    modules = @loader.all(locale: :es)

    assert_equal %w[design-for-longevity design-for-modularity design-for-recyclability zero-waste-design], modules.map(&:slug)
    assert_equal "Diseño para la longevidad", modules.first.title
    assert_includes modules.first.summary, "prendas"
    assert_equal "/content/training-modules/media/design-for-longevity/en/training-module/media/image1.png",
                 modules.first.cover
  end

  test "find returns a module by slug" do
    mod = @loader.find("zero-waste-design")
    assert_not_nil mod
    assert_equal "zero-waste-design", mod.slug
  end

  test "find returns nil for unknown slug" do
    assert_nil @loader.find("nonexistent-module")
  end

  test "module knows its available locales" do
    mod = @loader.find("zero-waste-design")
    assert_includes mod.available_locales, "en"
    assert_includes mod.available_locales, "es"
    assert_includes mod.available_locales, "it"
    assert_includes mod.available_locales, "el"
  end

  test "module knows its available sections" do
    mod = @loader.find("zero-waste-design")
    assert_includes mod.available_sections, "training-module"
    assert_includes mod.available_sections, "case-study"
    assert_includes mod.available_sections, "toolkit"
  end

  test "section returns parsed content for a valid combination" do
    section = @loader.section("zero-waste-design", "training-module", "en")
    assert_not_nil section
    assert_equal "Zero Waste Design", section.title
    assert_equal "zero-waste-design", section.module_slug
    assert_equal "en", section.locale
    assert_equal "training-module", section.volume
    assert section.body.present?
  end

  test "design for recyclability training module includes first chapter" do
    section = @loader.section("design-for-recyclability", "training-module", "en")
    assert_not_nil section
    assert_includes section.body, "# 1. Introduction to Design for Recyclability"
    assert section.body.index("# 1. Introduction to Design for Recyclability") < section.body.index("# 2. Historical Context")
  end

  test "section falls back for a missing locale and identifies the actual content locale" do
    section = @loader.section("zero-waste-design", "training-module", "fr")

    assert_equal "en", section.locale
    assert_equal "fr", section.requested_locale
    assert section.fallback?
  end

  test "section returns nil for missing section" do
    assert_nil @loader.section("zero-waste-design", "nonexistent", "en")
  end

  test "section returns nil for missing module" do
    assert_nil @loader.section("nonexistent", "training-module", "en")
  end

  test "about page loads for a given locale" do
    about = @loader.about("en")
    assert_not_nil about
    assert about.body.present?
  end

  test "about follows the shared locale fallback contract" do
    about = @loader.about("fr")

    assert_equal "en", about.locale
    assert about.fallback?
  end
end
