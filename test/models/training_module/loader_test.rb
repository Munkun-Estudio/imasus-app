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

  test "section returns nil for missing locale" do
    assert_nil @loader.section("zero-waste-design", "training-module", "fr")
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

  test "about returns nil for missing locale" do
    assert_nil @loader.about("fr")
  end
end
