require "test_helper"

class MaterialsHelperTest < ActionView::TestCase
  # --- materials_chip_toggle_url --------------------------------------------

  test "adds the slug to an empty facet" do
    url = materials_chip_toggle_url(
      "origin_type", "plants",
      selected_by_facet: {}
    )
    assert_equal "/materials?origin_type=plants", url
  end

  test "adds the slug to an existing list and preserves the others" do
    url = materials_chip_toggle_url(
      "origin_type", "seaweed",
      selected_by_facet: { "origin_type" => [ "plants" ] }
    )
    assert_equal "/materials?origin_type=plants%2Cseaweed", url
  end

  test "removes the slug when already selected and drops the facet if empty" do
    url = materials_chip_toggle_url(
      "origin_type", "plants",
      selected_by_facet: { "origin_type" => [ "plants" ] }
    )
    assert_equal "/materials", url
  end

  test "removes the slug but keeps other selections within the same facet" do
    url = materials_chip_toggle_url(
      "origin_type", "plants",
      selected_by_facet: { "origin_type" => [ "plants", "seaweed" ] }
    )
    assert_equal "/materials?origin_type=seaweed", url
  end

  test "preserves unrelated facets" do
    url = materials_chip_toggle_url(
      "application", "clothing",
      selected_by_facet: { "origin_type" => [ "plants" ] }
    )
    assert_includes url, "origin_type=plants"
    assert_includes url, "application=clothing"
  end

  test "preserves the search query" do
    url = materials_chip_toggle_url(
      "origin_type", "plants",
      selected_by_facet: {},
      query: "cypress"
    )
    assert_includes url, "origin_type=plants"
    assert_includes url, "q=cypress"
  end

  # --- materials_chip_active? -----------------------------------------------

  test "chip is active when its slug is in the facet's selected list" do
    assert materials_chip_active?("origin_type", "plants",
                                   selected_by_facet: { "origin_type" => [ "plants" ] })
  end

  test "chip is not active when its slug is absent" do
    assert_not materials_chip_active?("origin_type", "fungi",
                                       selected_by_facet: { "origin_type" => [ "plants" ] })
  end

  test "chip is not active when the facet is absent from selection" do
    assert_not materials_chip_active?("origin_type", "plants",
                                       selected_by_facet: {})
  end
end
