require "test_helper"

class ParticipantInvitationMailerTest < ActionMailer::TestCase
  test "invite renders recipient, workshop-aware subject, and tokenised URL" do
    workshop = Workshop.create!(title: "IMASUS Italy", location: "Prato")
    user = User.create!(name: "Part", email: "part@example.com", role: :participant)
    user.generate_invitation_token!

    email = ParticipantInvitationMailer.invite(user, user.invitation_token, workshop)

    assert_equal [ "part@example.com" ], email.to
    assert_includes email.subject, "IMASUS Italy"
    assert_includes email.body.encoded, user.invitation_token
    assert_match %r{/participant_invitations/[^/]+/edit}, email.body.encoded
  end
end
