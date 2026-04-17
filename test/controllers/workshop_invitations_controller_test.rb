require "test_helper"

class WorkshopInvitationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def setup
    @password = "correct horse battery staple"
    @admin       = User.create!(name: "Admin", email: "admin@example.com", password: @password, role: :admin)
    @facilitator = User.create!(name: "Fac",   email: "fac@example.com",   password: @password, role: :facilitator)
    @participant = User.create!(name: "Part",  email: "part@example.com",  password: @password, role: :participant)
    @workshop    = Workshop.create!(title: "IMASUS Spain", location: "Spain")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "unauthenticated GET new redirects to login" do
    get new_workshop_invitation_path(@workshop)
    assert_redirected_to new_session_path
  end

  test "participant is denied access" do
    sign_in(@participant)
    get new_workshop_invitation_path(@workshop)
    assert_redirected_to root_path
  end

  test "facilitator can open the form" do
    sign_in(@facilitator)
    get new_workshop_invitation_path(@workshop)
    assert_response :success
  end

  test "admin can open the form" do
    sign_in(@admin)
    get new_workshop_invitation_path(@workshop)
    assert_response :success
  end

  test "POST create invites new participants, skips existing, and emails only new ones" do
    sign_in(@facilitator)

    emails = [ "new1@example.com", "new2@example.com", @participant.email ]

    assert_emails 2 do
      assert_difference -> { User.participant.count }, 2 do
        assert_difference -> { WorkshopParticipation.count }, 3 do
          post workshop_invitations_path(@workshop), params: { emails: emails.join("\n") }
        end
      end
    end

    assert_redirected_to workshop_path(@workshop)

    new1 = User.find_by(email: "new1@example.com")
    assert new1.participant?
    assert new1.invitation_token.present?
    assert_includes @workshop.participants.reload, new1
    assert_includes @workshop.participants, @participant
  end

  test "POST create deduplicates emails in the same request" do
    sign_in(@facilitator)

    emails = "dup@example.com\nDUP@example.com\ndup@example.com"

    assert_emails 1 do
      assert_difference -> { User.participant.count }, 1 do
        post workshop_invitations_path(@workshop), params: { emails: emails }
      end
    end
  end

  test "POST create ignores blank lines and whitespace" do
    sign_in(@facilitator)
    post workshop_invitations_path(@workshop), params: { emails: "\n  one@example.com  \n\n" }
    assert User.find_by(email: "one@example.com").present?
  end

  test "POST create rejects malformed emails and does not create them" do
    sign_in(@facilitator)
    assert_no_difference -> { User.count } do
      post workshop_invitations_path(@workshop), params: { emails: "not-an-email" }
    end
  end

  test "POST create skips admin and facilitator accounts without creating participations" do
    sign_in(@facilitator)

    assert_no_difference -> { WorkshopParticipation.count } do
      assert_no_emails do
        post workshop_invitations_path(@workshop),
             params: { emails: "#{@admin.email}\n#{@facilitator.email}" }
      end
    end

    assert_not_includes @workshop.participants.reload, @admin
    assert_not_includes @workshop.participants, @facilitator
  end

  test "POST create does not duplicate an existing workshop participation" do
    sign_in(@facilitator)
    WorkshopParticipation.create!(user: @participant, workshop: @workshop)

    assert_no_difference -> { WorkshopParticipation.count } do
      post workshop_invitations_path(@workshop), params: { emails: @participant.email }
    end
  end
end
