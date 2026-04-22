require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def setup
    @user = User.create!(
      name: "Alex", email: "alex@example.com",
      password: "original password 123", role: :participant
    )
  end

  test "GET new renders the request form" do
    get new_password_reset_path
    assert_response :success
    assert_select "h1", text: I18n.t("password_resets.new.title")
    assert_select "input[type=email][class*=?]", "border"
    assert_select "input[type=submit][class*=?]", "bg-imasus-dark-green"
  end

  test "POST create sends email for a known user and shows generic confirmation" do
    assert_emails 1 do
      post password_resets_path, params: { email: @user.email }
    end
    assert_redirected_to new_session_path
    assert_not_nil flash[:notice]
    assert @user.reload.password_reset_token.present?
  end

  test "POST create does not send email for unknown user but shows the same confirmation" do
    assert_no_emails do
      post password_resets_path, params: { email: "ghost@example.com" }
    end
    assert_redirected_to new_session_path
    assert_not_nil flash[:notice]
  end

  test "POST create is case-insensitive on email" do
    assert_emails 1 do
      post password_resets_path, params: { email: "ALEX@Example.com" }
    end
  end

  test "GET edit with valid token renders the form" do
    @user.generate_password_reset_token!
    get edit_password_reset_path(token: @user.password_reset_token)
    assert_response :success
    assert_select "h1", text: I18n.t("password_resets.edit.title")
    assert_select "input[type=password][class*=?]", "border", count: 2
  end

  test "GET edit with expired token redirects to new with flash" do
    @user.update!(password_reset_token: "stale", password_reset_sent_at: 3.hours.ago)
    get edit_password_reset_path(token: "stale")
    assert_redirected_to new_password_reset_path
    assert_not_nil flash[:alert]
  end

  test "GET edit with unknown token redirects to new with flash" do
    get edit_password_reset_path(token: "nope")
    assert_redirected_to new_password_reset_path
    assert_not_nil flash[:alert]
  end

  test "PATCH update with valid token changes the password and clears the token" do
    @user.generate_password_reset_token!
    token = @user.password_reset_token

    patch password_reset_path(token: token), params: {
      password: "brand new secret 42", password_confirmation: "brand new secret 42"
    }

    assert_redirected_to new_session_path
    @user.reload
    assert_nil @user.password_reset_token
    assert_nil @user.password_reset_sent_at
    assert @user.authenticate("brand new secret 42")
  end

  test "PATCH update rejects mismatched confirmation" do
    @user.generate_password_reset_token!
    token = @user.password_reset_token

    patch password_reset_path(token: token), params: {
      password: "a-valid-pw-x", password_confirmation: "mismatch"
    }

    assert_response :unprocessable_content
    @user.reload
    assert @user.password_reset_token.present?, "token must not be consumed on failed update"
  end

  test "PATCH update with expired token redirects" do
    @user.update!(password_reset_token: "stale", password_reset_sent_at: 3.hours.ago)
    patch password_reset_path(token: "stale"), params: {
      password: "x", password_confirmation: "x"
    }
    assert_redirected_to new_password_reset_path
  end
end
