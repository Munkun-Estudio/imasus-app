require "test_helper"

class FacilitatorInvitationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @facilitator = User.create!(name: "F", email: "f@example.com", role: :facilitator)
    @facilitator.generate_invitation_token!
    @token = @facilitator.invitation_token
  end

  test "GET edit with valid token renders the form" do
    get edit_facilitator_invitation_path(token: @token)
    assert_response :success
  end

  test "GET edit with expired token shows error" do
    @facilitator.update!(invitation_sent_at: 8.days.ago)
    get edit_facilitator_invitation_path(token: @token)
    assert_redirected_to new_session_path
    assert_not_nil flash[:alert]
  end

  test "GET edit with unknown token shows error" do
    get edit_facilitator_invitation_path(token: "nope")
    assert_redirected_to new_session_path
    assert_not_nil flash[:alert]
  end

  test "PATCH update sets password, clears token, signs in, redirects to admin root" do
    patch facilitator_invitation_path(token: @token), params: {
      user: { name: "Updated", password: "fresh password 42", password_confirmation: "fresh password 42" }
    }

    @facilitator.reload
    assert_nil @facilitator.invitation_token
    assert_not_nil @facilitator.invitation_accepted_at
    assert_equal "Updated", @facilitator.name
    assert @facilitator.authenticate("fresh password 42")
    assert_redirected_to admin_root_path
    assert_equal @facilitator.id, session[:user_id]
  end

  test "PATCH update rejects mismatched confirmation" do
    patch facilitator_invitation_path(token: @token), params: {
      user: { name: "X", password: "fresh password 42", password_confirmation: "other" }
    }
    assert_response :unprocessable_content
    @facilitator.reload
    assert @facilitator.invitation_token.present?, "token must not be consumed on failure"
    assert_nil @facilitator.invitation_accepted_at
  end

  test "PATCH update on expired token is rejected" do
    @facilitator.update!(invitation_sent_at: 8.days.ago)
    patch facilitator_invitation_path(token: @token), params: {
      user: { name: "X", password: "whatever 42 x", password_confirmation: "whatever 42 x" }
    }
    assert_redirected_to new_session_path
  end
end
