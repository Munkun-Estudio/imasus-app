require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      trade_name:              "Pyratex Musa 1",
      supplier_name:           "PYRATEX",
      supplier_url:            "https://eshop.pyratex.com/shop/swaknribmu001",
      material_of_origin:      "Abaca",
      availability_status:     "commercial",
      position:                10,
      description_translations: {
        "en" => "The PYRATEX musa 1 rib is made from organic cotton and abaca fiber."
      }
    }.merge(overrides)
  end

  # --- Translatable: readers -------------------------------------------------

  test "description reads from the current locale" do
    record = Material.new(description_translations: { "en" => "A fiber", "es" => "Una fibra" })
    assert_equal "A fiber",   I18n.with_locale(:en) { record.description }
    assert_equal "Una fibra", I18n.with_locale(:es) { record.description }
  end

  test "description falls back to English when current locale is missing" do
    record = Material.new(description_translations: { "en" => "A fiber" })
    assert_equal "A fiber", I18n.with_locale(:it) { record.description }
  end

  test "translatable narrative fields are all declared" do
    record = Material.new(
      interesting_properties_translations: { "en" => "Breathable" },
      structure_translations:              { "en" => "Knit" },
      sensorial_qualities_translations:    { "en" => "Soft, warm" },
      what_problem_it_solves_translations: { "en" => "Replaces nylon" }
    )

    I18n.with_locale(:en) do
      assert_equal "Breathable",     record.interesting_properties
      assert_equal "Knit",           record.structure
      assert_equal "Soft, warm",     record.sensorial_qualities
      assert_equal "Replaces nylon", record.what_problem_it_solves
    end
  end

  # --- Validations -----------------------------------------------------------

  test "valid with trade_name, availability_status, and a base-locale description" do
    assert Material.new(valid_attributes).valid?
  end

  test "requires a trade_name" do
    record = Material.new(valid_attributes(trade_name: nil))
    assert_not record.valid?
    assert record.errors[:trade_name].any?
  end

  test "requires a base-locale (English) description" do
    record = Material.new(valid_attributes(description_translations: { "es" => "Una fibra" }))
    assert_not record.valid?
    assert record.errors[:description_translations].any?
  end

  test "requires an availability_status" do
    record = Material.new(valid_attributes(availability_status: nil))
    assert_not record.valid?
    assert record.errors[:availability_status].any?
  end

  test "rejects an unknown availability_status" do
    assert_raises ArgumentError do
      Material.new(valid_attributes(availability_status: "unknown"))
    end
  end

  test "accepts each of the three canonical availability statuses" do
    %w[commercial in_development research_only].each_with_index do |status, i|
      record = Material.new(valid_attributes(
        availability_status: status,
        trade_name:          "Material #{i}"
      ))
      assert record.valid?, "expected '#{status}' to validate: #{record.errors.full_messages.to_sentence}"
    end
  end

  # --- Slug ------------------------------------------------------------------

  test "generates a URL-safe slug from trade_name on create" do
    record = Material.create!(valid_attributes)
    assert_equal "pyratex-musa-1", record.slug
  end

  test "slug is not regenerated when trade_name changes" do
    record = Material.create!(valid_attributes)
    original = record.slug
    record.update!(trade_name: "Pyratex Musa 1 Renamed")
    assert_equal original, record.slug
  end

  test "to_param returns the slug" do
    record = Material.create!(valid_attributes)
    assert_equal record.slug, record.to_param
  end

  test "enforces case-insensitive slug uniqueness" do
    Material.create!(valid_attributes)
    dup = Material.new(valid_attributes(trade_name: "PYRATEX MUSA 1"))
    assert_not dup.valid?
    assert dup.errors[:slug].any?
  end

  test "slug is URL-safe for trade names with punctuation" do
    record = Material.create!(valid_attributes(trade_name: "B.Zornoza- Chitosan!"))
    assert_equal "b-zornoza-chitosan", record.slug
  end

  # --- Tags ------------------------------------------------------------------

  test "tags_for(facet) returns only tags for the given facet" do
    material = Material.create!(valid_attributes)
    plants   = Tag.create!(facet: "origin_type",       slug: "plants",   name_translations: { "en" => "Plants" })
    leather  = Tag.create!(facet: "textile_imitating", slug: "leather",  name_translations: { "en" => "Leather" })
    clothing = Tag.create!(facet: "application",       slug: "clothing", name_translations: { "en" => "Clothing" })

    material.tags << [ plants, leather, clothing ]

    assert_equal [ plants ],   material.tags_for(:origin_type)
    assert_equal [ leather ],  material.tags_for(:textile_imitating)
    assert_equal [ clothing ], material.tags_for(:application)
  end

  test "tags_for accepts string facet names" do
    material = Material.create!(valid_attributes)
    plants   = Tag.create!(facet: "origin_type", slug: "plants", name_translations: { "en" => "Plants" })
    material.tags << plants

    assert_equal [ plants ], material.tags_for("origin_type")
  end
end
