# Delivers the one-time password-reset link to a user who requested it.
# The token is passed by the controller because it is only known in-memory
# at that point — the stored column contains the same value, but keeping
# the parameter explicit avoids any ambiguity.
class PasswordResetMailer < ApplicationMailer
  def reset(user, token)
    @user  = user
    @url   = edit_password_reset_url(token: token)

    mail(
      to:      @user.email,
      subject: t("password_reset_mailer.reset.subject", default: "Reset your IMASUS password")
    )
  end
end
