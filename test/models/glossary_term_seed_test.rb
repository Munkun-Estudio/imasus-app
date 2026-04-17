require "test_helper"

class GlossaryTermSeedTest < ActiveSupport::TestCase
  test "seed_from_yaml! loads every entry from the default seed file" do
    GlossaryTerm.seed_from_yaml!
    entries = YAML.load_file(Rails.root.join("db", "seeds", "glossary_terms.yml"))

    assert_equal entries.size, GlossaryTerm.count
  end

  test "seed_from_yaml! is idempotent when run twice" do
    GlossaryTerm.seed_from_yaml!
    initial_count = GlossaryTerm.count
    GlossaryTerm.seed_from_yaml!

    assert_equal initial_count, GlossaryTerm.count
  end

  test "seed_from_yaml! applies translations to known terms" do
    GlossaryTerm.seed_from_yaml!
    framework = GlossaryTerm.find_by(slug: "framework")

    assert_not_nil framework
    assert_equal "Framework", I18n.with_locale(:en) { framework.term }
    assert_equal "Marco",     I18n.with_locale(:es) { framework.term }
    assert_equal "Quadro",    I18n.with_locale(:it) { framework.term }
  end

  test "seed covers all four canonical categories and meets the 10-term floor" do
    GlossaryTerm.seed_from_yaml!

    assert_operator GlossaryTerm.count, :>=, 10
    categories = GlossaryTerm.distinct.pluck(:category).sort
    assert_equal %w[application industry methodology science], categories
  end

  test "seed includes the crucial workshop vocabulary (imagineering, framework, workshop, project, team)" do
    GlossaryTerm.seed_from_yaml!

    %w[imagineering framework workshop project team].each do |slug|
      assert GlossaryTerm.exists?(slug: slug), "expected seed to include '#{slug}'"
    end
  end

  test "English definitions are present for every seed entry" do
    GlossaryTerm.seed_from_yaml!

    GlossaryTerm.find_each do |term|
      assert term.definition_in(:en).present?,
             "expected '#{term.slug}' to have an English definition"
    end
  end
end
