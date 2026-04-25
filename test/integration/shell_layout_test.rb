require "test_helper"

class ShellLayoutTest < ActionDispatch::IntegrationTest
  test "shell renders sidebar with all six navigation links" do
    get root_url
    assert_response :success

    assert_select "nav[aria-label] [data-role='primary-nav']" do
      assert_select "a", count: 6
      assert_select "a[href=?]", root_path
      assert_select "a[href=?]", workshops_path
      assert_select "a[href=?]", materials_path
      assert_select "a[href=?]", training_index_path
      assert_select "a[href=?]", challenges_path
      assert_select "a[href=?]", glossary_terms_path
    end
  end

  test "shell groups Materials, Training, Challenges, and Glossary under a Resources label" do
    get root_url
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "[data-group='resources']" do
        assert_select "a[href=?]", materials_path
        assert_select "a[href=?]", training_index_path
        assert_select "a[href=?]", challenges_path
        assert_select "a[href=?]", glossary_terms_path
      end
      assert_select "[data-role='resources-label']", /Resources/i
    end
  end

  test "shell no longer exposes the dropped Log and Prototype placeholders" do
    get root_url
    assert_response :success

    # Scope to the primary nav swatches; the user menu (auth chrome below
    # the swatches) legitimately contains a "Log in" link.
    assert_select "[data-role='primary-nav']" do
      assert_select "a", text: /Log/i, count: 0
      assert_select "a", text: /Prototype/i, count: 0
    end
  end

  test "Materials swatch uses the light-blue palette token (not red)" do
    get root_url
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "a[href=?].bg-imasus-light-blue", materials_path
      assert_select "a[href=?].bg-imasus-red", materials_path, count: 0
    end
  end

  test "Challenges swatch uses the mint palette token" do
    get root_url
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "a[href=?].bg-imasus-mint", challenges_path
    end
  end

  test "active navigation item has active CSS class" do
    get materials_url
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "a.nav-active[href=?]", materials_path
    end
  end

  test "active navigation item remains highlighted on nested pages" do
    Workshop.create!(
      slug: "spain",
      title_translations: { "en" => "Spain workshop" },
      description_translations: { "en" => "A workshop." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )

    get workshop_url("spain")
    assert_response :success

    assert_select "nav[aria-label]" do
      assert_select "a.nav-active[href=?]", workshops_path
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
