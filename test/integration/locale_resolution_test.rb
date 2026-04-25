require "test_helper"

# Exercises ApplicationController#set_locale across the visitor and
# authenticated paths. Resolution order:
#
#   1. params[:locale] (one-shot override)
#   2. current_user.preferred_locale (logged-in stored preference)
#   3. cookies[:locale] (visitor stickiness; existing behaviour)
#   4. I18n.default_locale
#
# I18n.locale resets after each request (set_locale uses I18n.with_locale
# as an around_action), so assertions read the layout's
# <html lang="..."> attribute instead of inspecting I18n.locale directly
# outside the request.
class LocaleResolutionTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @user = User.create!(
      name: "Pablo", email: "pablo@example.com",
      password: @password, role: :participant
    )
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  def assert_html_lang(locale)
    assert_match %r{<html lang="#{locale}"}, response.body
  end

  test "params[:locale] wins for the current request" do
    get root_url, params: { locale: "es" }
    assert_html_lang("es")
  end

  test "logged-in user with preferred_locale gets that locale without params" do
    @user.update!(preferred_locale: "it")
    sign_in(@user)

    get root_url
    assert_html_lang("it")
  end

  test "params[:locale] still wins over preferred_locale" do
    @user.update!(preferred_locale: "it")
    sign_in(@user)

    get root_url, params: { locale: "el" }
    assert_html_lang("el")
  end

  test "logged-in user without preferred_locale falls back to default" do
    sign_in(@user)
    cookies.delete(:locale)

    get root_url
    assert_html_lang(I18n.default_locale)
  end

  test "visitor without params or cookie sees default locale" do
    cookies.delete(:locale)

    get root_url
    assert_html_lang(I18n.default_locale)
  end

  test "invalid params[:locale] falls back to default without raising" do
    get root_url, params: { locale: "fr" }
    assert_response :success
    assert_html_lang(I18n.default_locale)
  end

  test "param override does not persist into preferred_locale" do
    @user.update!(preferred_locale: "en")
    sign_in(@user)

    get root_url, params: { locale: "es" }
    @user.reload
    assert_equal "en", @user.preferred_locale
  end
end
