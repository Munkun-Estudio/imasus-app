require "test_helper"

class TagSeedTest < ActiveSupport::TestCase
  test "seed_from_yaml! loads every entry from the default seed file" do
    Tag.seed_from_yaml!
    entries = YAML.load_file(Rails.root.join("db", "seeds", "material_tags.yml"))

    assert_equal entries.size, Tag.count
  end

  test "seed_from_yaml! is idempotent when run twice" do
    Tag.seed_from_yaml!
    initial_count = Tag.count
    Tag.seed_from_yaml!

    assert_equal initial_count, Tag.count
  end

  test "seed covers all three facets with non-empty vocabularies" do
    Tag.seed_from_yaml!

    %w[origin_type textile_imitating application].each do |facet|
      assert Tag.where(facet: facet).any?, "expected '#{facet}' to be seeded"
    end
  end

  test "seed includes the canonical origin_type vocabulary" do
    Tag.seed_from_yaml!
    slugs = Tag.where(facet: "origin_type").pluck(:slug).sort

    assert_equal %w[animals bacteria fungi microbial plants protein recycled_materials seaweed], slugs
  end

  test "English names are present for every seed entry" do
    Tag.seed_from_yaml!

    Tag.find_each do |tag|
      assert tag.name_in(:en).present?, "expected '#{tag.facet}/#{tag.slug}' to have an English name"
    end
  end
end
