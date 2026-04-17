require "test_helper"

class PasswordResetMailerTest < ActionMailer::TestCase
  test "reset renders recipient, subject, and tokenised URL" do
    user = User.create!(name: "User", email: "user@example.com", password: "correct horse battery staple", role: :participant)
    user.generate_password_reset_token!

    email = PasswordResetMailer.reset(user, user.password_reset_token)

    assert_equal [ "user@example.com" ], email.to
    assert_match(/reset/i, email.subject)
    assert_includes email.body.encoded, user.password_reset_token
    assert_match %r{/password_resets/[^/]+/edit}, email.body.encoded
  end
end
