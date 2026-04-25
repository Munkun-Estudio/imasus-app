require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @user = User.create!(
      name: "Alex", email: "alex@example.com",
      password: @password, role: :participant
    )
  end

  test "GET new renders the login form" do
    get new_session_path
    assert_response :success
    assert_select "h1", text: I18n.t("sessions.new.title")
    assert_select "input[type=email][class*=?]", "border"
    assert_select "input[type=password][class*=?]", "border"
    assert_select "input[type=submit][class*=?]", "bg-imasus-dark-green"
    assert_select "a", text: I18n.t("sessions.new.forgot")
  end

  test "POST create with valid credentials signs in and redirects" do
    post session_path, params: { email: @user.email, password: @password }
    assert_redirected_to root_path
    assert_equal @user.id, session[:user_id]
  end

  test "POST create is case-insensitive on email" do
    post session_path, params: { email: "ALEX@example.com", password: @password }
    assert_equal @user.id, session[:user_id]
  end

  test "POST create with wrong password does not sign in" do
    post session_path, params: { email: @user.email, password: "nope" }
    assert_response :unprocessable_content
    assert_nil session[:user_id]
    assert_not_nil flash.now[:alert]
  end

  test "POST create with unknown email uses the same generic message" do
    post session_path, params: { email: "ghost@example.com", password: "x" }
    assert_response :unprocessable_content
    assert_nil session[:user_id]
    assert_not_nil flash.now[:alert]
  end

  test "POST create rejects users without a password digest (pre-invitation)" do
    invitee = User.create!(name: "I", email: "i@example.com", role: :facilitator)
    post session_path, params: { email: invitee.email, password: "" }
    assert_nil session[:user_id]
  end

  test "DELETE destroy clears the session" do
    post session_path, params: { email: @user.email, password: @password }
    assert_equal @user.id, session[:user_id]
    delete session_path
    assert_nil session[:user_id]
    assert_redirected_to new_session_path
  end

  test "POST create honours stored return_to" do
    get admin_facilitators_path
    assert_redirected_to new_session_path

    post session_path, params: { email: @user.email, password: @password }
    assert_redirected_to admin_facilitators_path
  end
end
