require "test_helper"

class ParticipantInvitationMailerTest < ActionMailer::TestCase
  test "invite renders recipient, workshop-aware subject, and tokenised URL" do
    workshop = Workshop.create!(
      slug: "spain",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    user = User.create!(name: "Part", email: "part@example.com", role: :participant)
    user.generate_invitation_token!

    email = ParticipantInvitationMailer.invite(user, user.invitation_token, workshop)

    assert_equal [ "part@example.com" ], email.to
    assert_includes email.subject, "Taller IMASUS Espana"
    assert_includes email.body.encoded, user.invitation_token
    assert_includes email.subject, "Te han invitado"
    assert_includes email.body.encoded, "Hola,"
    assert_match %r{/participant_invitations/[^/]+/edit\?locale=}, email.body.encoded
  end
end
