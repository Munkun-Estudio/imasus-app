require "test_helper"

class Admin::FacilitatorsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def setup
    @password = "correct horse battery staple"
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: @password, role: :admin)
    @facilitator = User.create!(name: "Fac", email: "fac@example.com", password: @password, role: :facilitator)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "unauthenticated GET index redirects to login" do
    get admin_facilitators_path
    assert_redirected_to new_session_path
  end

  test "facilitator is denied access" do
    sign_in(@facilitator)
    get admin_facilitators_path
    assert_redirected_to root_path
  end

  test "admin can see the index" do
    sign_in(@admin)
    get admin_facilitators_path
    assert_response :success
  end

  test "admin can open the new form" do
    sign_in(@admin)
    get new_admin_facilitator_path
    assert_response :success
  end

  test "admin creates a facilitator, sends invitation email, and redirects" do
    sign_in(@admin)
    assert_emails 1 do
      assert_difference -> { User.facilitator.count }, 1 do
        post admin_facilitators_path, params: { user: { name: "New Fac", email: "new@example.com" } }
      end
    end
    created = User.find_by(email: "new@example.com")
    assert created.facilitator?
    assert created.invitation_token.present?
    assert_redirected_to admin_facilitators_path
  end

  test "creation is rejected when email is already taken" do
    sign_in(@admin)
    assert_no_emails do
      assert_no_difference -> { User.count } do
        post admin_facilitators_path, params: { user: { name: "Dup", email: @facilitator.email } }
      end
    end
    assert_response :unprocessable_content
  end

  test "creation rejects invalid email format" do
    sign_in(@admin)
    assert_no_emails do
      post admin_facilitators_path, params: { user: { name: "N", email: "not-an-email" } }
    end
    assert_response :unprocessable_content
  end
end
