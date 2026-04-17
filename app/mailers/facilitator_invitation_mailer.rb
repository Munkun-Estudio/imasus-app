# Sends the one-time invitation link that a new facilitator uses to set
# their password and activate their account.
class FacilitatorInvitationMailer < ApplicationMailer
  def invite(user, token)
    @user = user
    @url  = edit_facilitator_invitation_url(token: token)

    mail(
      to:      @user.email,
      subject: t("facilitator_invitation_mailer.invite.subject",
                 default: "You have been invited to IMASUS as a facilitator")
    )
  end
end
