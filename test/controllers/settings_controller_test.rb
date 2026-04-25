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

  test "GET edit renders all four form sections" do
    sign_in_as(@user)
    get edit_settings_path
    assert_select "[data-settings-section=account]"
    assert_select "[data-settings-section=password]"
    assert_select "[data-settings-section=profile]"
    assert_select "[data-settings-section=preferences]"
  end

  test "PATCH update saves name and email" do
    sign_in_as(@user)
    patch settings_path, params: {
      user: { name: "New Name", email: "new@example.com" }
    }
    assert_redirected_to edit_settings_path
    @user.reload
    assert_equal "New Name", @user.name
    assert_equal "new@example.com", @user.email
  end

  test "PATCH update with empty password fields leaves password unchanged" do
    sign_in_as(@user)
    digest_before = @user.password_digest
    patch settings_path, params: {
      user: { name: "Pablo Updated",
              current_password: "",
              password: "",
              password_confirmation: "" }
    }
    @user.reload
    assert_equal "Pablo Updated", @user.name
    assert_equal digest_before, @user.password_digest
  end

  test "PATCH update with valid current_password and matching new password rotates the password" do
    sign_in_as(@user)
    new_password = "fresh password 42"
    patch settings_path, params: {
      user: { current_password: @password,
              password: new_password,
              password_confirmation: new_password }
    }
    assert_redirected_to edit_settings_path
    @user.reload
    assert @user.authenticate(new_password)
    assert_not @user.authenticate(@password)
  end

  test "PATCH update with wrong current_password rejects the password change" do
    sign_in_as(@user)
    patch settings_path, params: {
      user: { current_password: "WRONG",
              password: "new password 42",
              password_confirmation: "new password 42" }
    }
    assert_response :unprocessable_content
    @user.reload
    assert @user.authenticate(@password) # still the old one
  end

  test "PATCH update with mismatched confirmation rejects the password change" do
    sign_in_as(@user)
    patch settings_path, params: {
      user: { current_password: @password,
              password: "new password 42",
              password_confirmation: "other" }
    }
    assert_response :unprocessable_content
    @user.reload
    assert @user.authenticate(@password)
  end

  test "PATCH update saves profile fields" do
    sign_in_as(@user)
    patch settings_path, params: {
      user: { institution: "Munkun Labs", country: "ES",
              bio: "Designer.", links: "https://example.com" }
    }
    @user.reload
    assert_equal "Munkun Labs", @user.institution
    assert_equal "ES", @user.country
    assert_equal "Designer.", @user.bio
    assert_equal "https://example.com", @user.links
  end

  test "PATCH update saves preferred_locale" do
    sign_in_as(@user)
    patch settings_path, params: { user: { preferred_locale: "it" } }
    @user.reload
    assert_equal "it", @user.preferred_locale
  end

  test "PATCH update with empty preferred_locale clears the stored preference" do
    @user.update!(preferred_locale: "es")
    sign_in_as(@user)
    patch settings_path, params: { user: { preferred_locale: "" } }
    @user.reload
    assert_nil @user.preferred_locale
  end
end
