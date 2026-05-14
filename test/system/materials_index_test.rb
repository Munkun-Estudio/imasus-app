require "application_system_test_case"

class MaterialsIndexTest < ApplicationSystemTestCase
  setup do
    Tag.seed_from_yaml!
    Material.seed_from_yaml!
  end

  test "toggling chips across two facets narrows the grid" do
    visit materials_url

    total = all("[data-material]").count
    assert total > 0

    # Toggle an origin_type chip: the URL gains the facet param and the
    # grid shrinks.
    within("[data-facet='origin_type']") do
      find("[data-chip-slug='plants']").click
    end
    assert_current_path(/origin_type=plants/)
    plants_total = all("[data-material]").count
    plant_slugs = Tag.find_by!(facet: "origin_type", slug: "plants").materials.pluck(:slug)
    all("[data-material]").each do |card|
      assert_includes plant_slugs, card["data-material"]
    end

    # Add an application chip: still narrower, AND semantics across facets.
    within("[data-facet='application']") do
      find("[data-chip-slug='clothing']").click
    end
    assert_current_path(/origin_type=plants/)
    assert_current_path(/application=clothing/)
    and_total = all("[data-material]").count
    assert and_total <= plants_total,
           "expected AND-across-facets result to be no larger than the plants-only result"
    clothing_slugs = Tag.find_by!(facet: "application", slug: "clothing").materials.pluck(:slug)
    all("[data-material]").each do |card|
      assert_includes plant_slugs, card["data-material"]
      assert_includes clothing_slugs, card["data-material"]
    end

    # Clear all → back to full grid.
    find("[data-role='clear-all']").click
    assert_current_path materials_path
    assert_equal total, all("[data-material]").count
  end

  test "searching for a term that matches nothing shows the empty state" do
    visit materials_url

    fill_in "q", with: "zzz-no-such-material-zzz"
    find("input[name='q']").send_keys(:enter)

    assert_selector "[data-role='empty-state']"
    assert_no_selector "[data-material]"
  end

  test "cards are wired with the card-media Stimulus controller" do
    visit materials_url

    assert_selector "[data-controller~='card-media'][data-material]",
                    minimum: 1
  end

  test "eye icon opens the preview sidebar, Escape dismisses it" do
    visit materials_url

    first_card = first("[data-material]")
    slug = first_card["data-material"]
    within(first_card) do
      find("[data-role='open-preview']").click
    end

    assert_selector "turbo-frame#preview [role='dialog']"
    assert_selector "turbo-frame#preview a[href='#{material_path(slug)}']"

    find("body").send_keys(:escape)

    assert_no_selector "turbo-frame#preview [role='dialog']"
  end

  test "re-clicking the same eye icon after closing re-opens the preview" do
    material = Material.order(:position).first
    visit materials_url

    within("[data-material='#{material.slug}']") do
      find("[data-role='open-preview']").click
    end
    assert_selector "turbo-frame#preview [role='dialog']"

    find("body").send_keys(:escape)
    assert_no_selector "turbo-frame#preview [role='dialog']"

    within("[data-material='#{material.slug}']") do
      find("[data-role='open-preview']").click
    end
    assert_selector "turbo-frame#preview [role='dialog']"
  end

  test "preview sidebar link navigates to the material detail page" do
    material = Material.order(:position).first
    visit materials_url

    within("[data-material='#{material.slug}']") do
      find("[data-role='open-preview']").click
    end

    within("turbo-frame#preview") do
      click_link I18n.t("materials.preview.open_full_page")
    end

    assert_current_path material_path(material.slug)
    assert_selector "h1", text: material.trade_name
  end
end
