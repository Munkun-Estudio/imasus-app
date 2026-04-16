require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url

    assert_response :success
    assert_includes response.body, I18n.t("home.index.heading")
  end
end
