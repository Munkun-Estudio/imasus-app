require "test_helper"

class ShellLayoutTest < ActionDispatch::IntegrationTest
  test "shell renders sidebar with all seven navigation links" do
    get root_url
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "a", minimum: 7
      assert_select "a[href=?]", root_path
      assert_select "a[href=?]", materials_path
      assert_select "a[href=?]", training_index_path
      assert_select "a[href=?]", workshops_path
      assert_select "a[href=?]", log_index_path
      assert_select "a[href=?]", prototype_index_path
      assert_select "a[href=?]", glossary_index_path
    end
  end

  test "active navigation item has active CSS class" do
    get materials_url
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "a.nav-active[href=?]", materials_path
    end
  end

  test "footer renders EU funding notice" do
    get root_url
    assert_response :success

    assert_select "footer" do
      assert_select "p", /Funded by the European Union/
    end
  end

  test "footer renders partner logos" do
    get root_url
    assert_response :success

    assert_select "footer" do
      %w[INMA Lottozero ECHN Munkun].each do |partner|
        assert_select "img[alt*=?]", partner
      end
    end
  end

  test "locale switcher is present in the shell" do
    get root_url
    assert_response :success

    assert_select "[data-controller='locale-switcher']" do
      assert_select "a", minimum: 4
    end
  end

  test "locale switch via param changes language and sets cookie" do
    get root_url, params: { locale: "es" }
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "a", /Inicio/
    end

    assert_equal "es", cookies[:locale]
  end

  test "locale persists via cookie across requests" do
    get root_url, params: { locale: "it" }
    assert_equal "it", cookies[:locale]

    get root_url
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "a", /Formazione/
    end
  end
end
