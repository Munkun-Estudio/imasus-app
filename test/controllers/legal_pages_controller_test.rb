require "test_helper"

class LegalPagesControllerTest < ActionDispatch::IntegrationTest
  test "privacy page is public and explains app-specific data use" do
    get privacy_url

    assert_response :success
    assert_select "h1", text: "Privacy Policy"
    assert_select "p", text: /participant profile cards/i
    assert_select "p", text: /Plausible Analytics/i
    assert_select "li", text: /Locale cookie/i
    assert_select "p", text: /we do not show a cookie consent banner/i
  end

  test "terms page is public and explains project publication responsibilities" do
    get terms_url

    assert_response :success
    assert_select "h1", text: "Terms of Use"
    assert_select "p", text: /When a project is published/i
    assert_select "p", text: /Facilitators and administrators may disable/i
  end

  test "footer links to legal pages" do
    get root_url

    assert_response :success
    assert_select "footer a[href=?]", privacy_path, text: I18n.t("footer.privacy")
    assert_select "footer a[href=?]", terms_path, text: I18n.t("footer.terms")
  end

  test "plausible analytics script renders in production layout" do
    original_env = Rails.instance_variable_get(:@_env)
    Rails.instance_variable_set(:@_env, ActiveSupport::EnvironmentInquirer.new("production"))

    get root_url

    assert_response :success
    assert_select "script[src=?]", "https://stats.munkun.com/js/pa-AEv3S9_hJMk___wHOsvRL.js"
    assert_includes response.body, "plausible.init()"
  ensure
    Rails.instance_variable_set(:@_env, original_env)
  end
end
