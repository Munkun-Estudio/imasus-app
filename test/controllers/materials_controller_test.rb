require "test_helper"

class MaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Tag.seed_from_yaml!
    Material.seed_from_yaml!
  end

  # Matches the per-card marker rendered in the view so we can assert
  # presence, counts, and ordering without being coupled to CSS classes.
  def card_selector(material = nil)
    material ? %([data-material="#{material.slug}"]) : "[data-material]"
  end

  # --- Basic rendering ------------------------------------------------------

  test "GET /materials returns 200" do
    get materials_url
    assert_response :success
  end

  test "GET /materials lists every seeded material" do
    get materials_url
    Material.find_each do |material|
      assert_select card_selector(material)
    end
  end

  test "GET /materials renders materials ordered by position" do
    get materials_url
    slugs_in_render = css_select(card_selector).map { |node| node["data-material"] }
    expected = Material.order(:position).pluck(:slug)
    assert_equal expected, slugs_in_render
  end

  test "GET /materials renders the trade name for each material" do
    get materials_url
    Material.find_each do |material|
      assert_includes response.body, material.trade_name
    end
  end

  # --- Chip-filter rail ------------------------------------------------------

  test "GET /materials renders a chip for every seeded tag, grouped by facet" do
    get materials_url
    Tag::FACETS.each do |facet|
      Tag.where(facet: facet).find_each do |tag|
        assert_select %([data-facet="#{facet}"] a[href*="#{facet}=#{tag.slug}"]),
                      minimum: 1,
                      message: "expected a chip link for facet=#{facet} slug=#{tag.slug}"
      end
    end
  end

  # --- Filtering: within-facet OR --------------------------------------------

  test "GET /materials?origin_type=plants narrows to materials tagged with plants" do
    get materials_url(origin_type: "plants")
    tag = Tag.find_by!(facet: "origin_type", slug: "plants")
    tagged   = tag.materials.pluck(:slug).uniq
    untagged = Material.where.not(id: tag.materials.select(:id)).pluck(:slug)

    tagged.each { |slug| assert_select %([data-material="#{slug}"]) }
    untagged.each { |slug| assert_select %([data-material="#{slug}"]), count: 0 }
  end

  test "GET /materials?origin_type=plants,seaweed unions slugs (OR within facet)" do
    get materials_url(origin_type: "plants,seaweed")
    plants  = Tag.find_by!(facet: "origin_type", slug: "plants")
    seaweed = Tag.find_by!(facet: "origin_type", slug: "seaweed")
    union = (plants.materials.pluck(:id) | seaweed.materials.pluck(:id))
    expected_slugs = Material.where(id: union).pluck(:slug)

    expected_slugs.each { |slug| assert_select %([data-material="#{slug}"]) }
    Material.where.not(id: union).pluck(:slug).each do |slug|
      assert_select %([data-material="#{slug}"]), count: 0
    end
  end

  # --- Filtering: across-facet AND -------------------------------------------

  test "GET /materials with two facets applies AND across them" do
    plants   = Tag.find_by!(facet: "origin_type", slug: "plants")
    clothing = Tag.find_by!(facet: "application", slug: "clothing")
    expected_ids = plants.materials.pluck(:id) & clothing.materials.pluck(:id)

    get materials_url(origin_type: "plants", application: "clothing")

    expected_slugs = Material.where(id: expected_ids).pluck(:slug)
    expected_slugs.each { |slug| assert_select %([data-material="#{slug}"]) }
    Material.where.not(id: expected_ids).pluck(:slug).each do |slug|
      assert_select %([data-material="#{slug}"]), count: 0
    end
  end

  # --- Robustness: unknown chips --------------------------------------------

  test "GET /materials with an unknown chip slug is ignored, no error" do
    get materials_url(origin_type: "spaceship")
    assert_response :success
    Material.find_each do |material|
      assert_select card_selector(material)
    end
  end

  test "GET /materials with an unknown facet name is ignored, no error" do
    get materials_url(nonsense_facet: "anything")
    assert_response :success
    Material.find_each do |material|
      assert_select card_selector(material)
    end
  end

  # --- Search ---------------------------------------------------------------

  test "GET /materials?q=cypress narrows by trade_name" do
    get materials_url(q: "cypress")
    cypress = Material.find_by(slug: "lifematerials-cypress-denim")
    assert_not_nil cypress, "expected the Cypress Denim seed entry to exist"
    assert_select card_selector(cypress)
    # sanity: something that doesn't contain "cypress" in its trade name or
    # English description should not be in the filtered result
    unrelated = Material.where.not("LOWER(trade_name) LIKE ?", "%cypress%")
                         .where.not("description_translations->>'en' ILIKE ?", "%cypress%")
                         .first
    assert_not_nil unrelated
    assert_select %([data-material="#{unrelated.slug}"]), count: 0
  end

  test "GET /materials?q=... searches the current-locale description JSONB key" do
    needle = "quoquolorem"
    material = Material.create!(
      trade_name:               "Locale search probe",
      availability_status:      "commercial",
      description_translations: { "en" => "An English description.", "es" => "Contiene #{needle} aquí." }
    )

    I18n.with_locale(:es) do
      get materials_url(q: needle, locale: "es")
      assert_select %([data-material="#{material.slug}"])
    end

    I18n.with_locale(:en) do
      get materials_url(q: needle, locale: "en")
      assert_select %([data-material="#{material.slug}"]), count: 0
    end
  end

  test "GET /materials combines chip filters and search with AND" do
    plants = Tag.find_by!(facet: "origin_type", slug: "plants")
    cypress = Material.find_by(slug: "lifematerials-cypress-denim")
    assert_not_nil cypress
    # Ensure Cypress Denim is actually tagged as plants (seed invariant)
    assert_includes cypress.tags_for(:origin_type).pluck(:slug), "plants"

    get materials_url(origin_type: "plants", q: "cypress")

    assert_select card_selector(cypress)
    # a non-cypress plants material should be excluded
    other_plants = plants.materials
                         .where.not(id: cypress.id)
                         .where.not("LOWER(trade_name) LIKE ?", "%cypress%")
                         .first
    assert_not_nil other_plants
    assert_select %([data-material="#{other_plants.slug}"]), count: 0
  end

  test "GET /materials?q=nothingwillmatch renders the empty state" do
    get materials_url(q: "zzz-definitely-no-such-material-zzz")
    assert_response :success
    assert_select card_selector, count: 0
    assert_select "[data-role='empty-state']"
  end

  # --- Per-chip counts -------------------------------------------------------

  test "GET /materials renders a match count next to each chip" do
    get materials_url
    Tag::FACETS.each do |facet|
      Tag.where(facet: facet).find_each do |tag|
        expected = tag.materials.count
        assert_select %([data-facet="#{facet}"] [data-chip-slug="#{tag.slug}"] [data-role="chip-count"]),
                      text: expected.to_s,
                      message: "expected count=#{expected} for facet=#{facet} slug=#{tag.slug}"
      end
    end
  end

  # --- Clear-all control -----------------------------------------------------

  test "GET /materials with any filter shows a Clear all control" do
    get materials_url(origin_type: "plants")
    assert_select "a[data-role='clear-all'][href=?]", materials_path
  end

  test "GET /materials without filters does not show the Clear all control" do
    get materials_url
    assert_select "a[data-role='clear-all']", count: 0
  end

  # --- Card-media Stimulus wiring -------------------------------------------

  test "each rendered card has the card-media Stimulus controller wired" do
    get materials_url
    assert_select "[data-controller~='card-media']", minimum: Material.count
  end
end
