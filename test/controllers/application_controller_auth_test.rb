require "test_helper"

# Exercises the authentication helpers on ApplicationController through a
# concrete controller that opts into them.
class ApplicationControllerAuthTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: @password, role: :admin)
    @facilitator = User.create!(name: "Fac",   email: "fac@example.com",   password: @password, role: :facilitator)
    @participant = User.create!(name: "Part",  email: "part@example.com",  password: @password, role: :participant)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "unauthenticated access to admin area redirects to login and stores return path" do
    get admin_facilitators_path
    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
  end

  test "authenticated admin can access admin area" do
    sign_in(@admin)
    get admin_facilitators_path
    assert_response :success
  end

  test "facilitator is denied access to admin area" do
    sign_in(@facilitator)
    get admin_facilitators_path
    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end

  test "participant is denied access to admin area" do
    sign_in(@participant)
    get admin_facilitators_path
    assert_redirected_to root_path
  end
end
