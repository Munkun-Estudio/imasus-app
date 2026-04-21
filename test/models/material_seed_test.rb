require "test_helper"

class MaterialSeedTest < ActiveSupport::TestCase
  setup do
    Tag.seed_from_yaml!
  end

  test "seed_from_yaml! loads every entry from the default seed file" do
    Material.seed_from_yaml!
    entries = YAML.load_file(Rails.root.join("db", "seeds", "materials.yml"))

    assert_equal entries.size, Material.count
  end

  test "seed_from_yaml! is idempotent when run twice" do
    Material.seed_from_yaml!
    initial_count = Material.count
    Material.seed_from_yaml!

    assert_equal initial_count, Material.count
  end

  test "seed covers every reconciled material from the source doc" do
    Material.seed_from_yaml!

    # 57 = 58 trade names in docs/materials-db.md minus the Pyratex Seacell 7
    # duplicate that the parser merges (see the dedicated test below).
    assert_equal 57, Material.count
  end

  test "English descriptions are present for every seed entry" do
    Material.seed_from_yaml!

    Material.find_each do |material|
      assert material.description_in(:en).present?,
             "expected '#{material.slug}' to have an English description"
    end
  end

  test "seed associates canonical material entries with the correct tags" do
    Material.seed_from_yaml!

    cypress = Material.find_by(slug: "lifematerials-cypress-denim")
    assert_not_nil cypress, "expected Lifematerials Cypress Denim in the seed"

    origin_slugs = cypress.tags_for(:origin_type).pluck(:slug)
    imitating_slugs = cypress.tags_for(:textile_imitating).pluck(:slug)

    assert_includes origin_slugs, "plants"
    assert_includes imitating_slugs, "denim"
  end

  test "seed merges Pyratex Seacell 7 (listed twice in docs) into a single material with both origin tags" do
    Material.seed_from_yaml!

    matches = Material.where(slug: %w[pyratex-seacell-7 pyratex-seacell-7-1])
    assert_equal [ "pyratex-seacell-7" ], matches.pluck(:slug),
                 "expected exactly one Seacell 7 row — the Bamboo/Seaweed duplicate should be merged"

    seacell = matches.first
    origin_slugs = seacell.tags_for(:origin_type).pluck(:slug).sort
    assert_equal %w[plants seaweed], origin_slugs,
                 "expected the merged row to carry both plants and seaweed origin tags"
  end

  test "seed_from_yaml! raises a clear error when a material references an unknown tag slug" do
    entries = [
      {
        "trade_name"           => "Mystery material",
        "availability_status"  => "commercial",
        "description"          => { "en" => "A test material" },
        "tags"                 => { "origin_type" => [ "no-such-origin" ] }
      }
    ]

    path = Rails.root.join("tmp", "test-materials-#{SecureRandom.hex(4)}.yml")
    File.write(path, entries.to_yaml)

    error = assert_raises(ArgumentError) { Material.seed_from_yaml!(path: path) }
    assert_match(/no-such-origin/, error.message)
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
