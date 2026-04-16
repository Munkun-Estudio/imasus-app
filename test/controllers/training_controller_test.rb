require "test_helper"

class TrainingControllerTest < ActionDispatch::IntegrationTest
  test "index renders successfully" do
    get training_index_url
    assert_response :success
  end

  test "index lists all four modules as links" do
    get training_index_url
    assert_response :success

    %w[zero-waste-design design-for-longevity design-for-modularity design-for-recyclability].each do |slug|
      assert_select "a[href*='#{slug}/training-module']"
    end
  end

  test "show renders a module section" do
    get training_show_url(slug: "zero-waste-design", section: "training-module")
    assert_response :success
  end

  test "show renders markdown content as HTML" do
    get training_show_url(slug: "zero-waste-design", section: "training-module")
    assert_response :success
    assert_select "h1"
  end

  test "show returns 404 for unknown module" do
    get training_show_url(slug: "nonexistent", section: "training-module")
    assert_response :not_found
  end

  test "show returns 404 for unknown section" do
    get training_show_url(slug: "zero-waste-design", section: "nonexistent")
    assert_response :not_found
  end

  test "show respects locale param" do
    get training_show_url(slug: "zero-waste-design", section: "training-module", locale: "es")
    assert_response :success
  end

  test "chapter navigation links are present" do
    get training_show_url(slug: "zero-waste-design", section: "training-module")
    assert_response :success
    assert_select "a", /case-study|toolkit/i
  end

  test "first section has no previous link" do
    get training_show_url(slug: "zero-waste-design", section: "training-module")
    assert_response :success
    assert_select "[data-nav='previous']", count: 0
  end

  test "last section has no next link" do
    get training_show_url(slug: "zero-waste-design", section: "case-study")
    assert_response :success
    assert_select "[data-nav='next']", count: 0
  end

  test "locale switcher links to same module in other locales" do
    get training_show_url(slug: "zero-waste-design", section: "training-module")
    assert_response :success

    assert_select "[data-training-locale-switcher]" do
      assert_select "a[href*='locale=es']"
      assert_select "a[href*='locale=it']"
      assert_select "a[href*='locale=el']"
    end
  end
end
