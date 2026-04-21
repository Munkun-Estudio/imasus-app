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
    assert plants_total < total,
           "expected fewer cards after selecting origin_type=plants"

    # Add an application chip: still narrower, AND semantics across facets.
    within("[data-facet='application']") do
      find("[data-chip-slug='clothing']").click
    end
    assert_current_path(/origin_type=plants/)
    assert_current_path(/application=clothing/)
    and_total = all("[data-material]").count
    assert and_total <= plants_total,
           "expected AND-across-facets result to be no larger than the plants-only result"

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
end
