require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @user = User.create!(
      name: "Pablo", email: "pablo@example.com",
      password: @password, role: :participant
    )
  end

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "routes /settings/edit and PATCH /settings to the SettingsController" do
    assert_routing({ method: "get", path: "/settings/edit" },
                   controller: "settings", action: "edit")
    assert_routing({ method: "patch", path: "/settings" },
                   controller: "settings", action: "update")
  end

  test "GET edit redirects unauthenticated requests to login" do
    get edit_settings_path
    assert_redirected_to new_session_path
  end

  test "GET edit renders for authenticated users" do
    sign_in_as(@user)
    get edit_settings_path
    assert_response :success
  end
end
