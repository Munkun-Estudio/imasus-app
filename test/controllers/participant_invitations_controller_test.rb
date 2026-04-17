require "test_helper"

class ParticipantInvitationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @workshop = Workshop.create!(title: "IMASUS Italy", location: "Italy")
    @participant = User.create!(name: "P", email: "p@example.com", role: :participant)
    @participant.generate_invitation_token!
    WorkshopParticipation.create!(user: @participant, workshop: @workshop)
    @token = @participant.invitation_token
  end

  test "GET edit with valid token renders" do
    get edit_participant_invitation_path(token: @token)
    assert_response :success
  end

  test "GET edit with expired token redirects with error" do
    @participant.update!(invitation_sent_at: 15.days.ago)
    get edit_participant_invitation_path(token: @token)
    assert_redirected_to new_session_path
    assert_not_nil flash[:alert]
  end

  test "GET edit with unknown token redirects with error" do
    get edit_participant_invitation_path(token: "nope")
    assert_redirected_to new_session_path
  end

  test "PATCH update completes registration and redirects to workshop" do
    patch participant_invitation_path(token: @token), params: {
      user: {
        name: "Paula Participant",
        institution: "Uni",
        country: "ES",
        bio: "Student of design.",
        links: "https://example.com/paula",
        password: "fresh password 42",
        password_confirmation: "fresh password 42"
      }
    }

    @participant.reload
    assert_equal "Paula Participant", @participant.name
    assert_equal "Uni", @participant.institution
    assert_equal "ES",  @participant.country
    assert @participant.authenticate("fresh password 42")
    assert_nil @participant.invitation_token
    assert_not_nil @participant.invitation_accepted_at
    assert_redirected_to workshop_path(@workshop)
    assert_equal @participant.id, session[:user_id]
  end

  test "PATCH update with missing required field re-renders" do
    patch participant_invitation_path(token: @token), params: {
      user: { name: "", password: "fresh password 42", password_confirmation: "fresh password 42" }
    }
    assert_response :unprocessable_content
    @participant.reload
    assert @participant.invitation_token.present?
  end
end
