require "test_helper"

class FacilitatorInvitationMailerTest < ActionMailer::TestCase
  test "invite renders recipient, subject, and tokenised URL" do
    user = User.create!(name: "Fac", email: "fac@example.com", role: :facilitator)
    user.generate_invitation_token!

    email = FacilitatorInvitationMailer.invite(user, user.invitation_token)

    assert_equal [ "fac@example.com" ], email.to
    assert_match(/facilitator/i, email.subject)
    assert_includes email.body.encoded, user.invitation_token
    assert_match %r{/facilitator_invitations/[^/]+/edit}, email.body.encoded
  end
end
