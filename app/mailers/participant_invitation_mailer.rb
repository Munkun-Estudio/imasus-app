# Sends the one-time invitation link that a participant uses to complete
# their registration and join a workshop.
class ParticipantInvitationMailer < ApplicationMailer
  def invite(user, token, workshop)
    @user     = user
    @workshop = workshop
    locale    = workshop.communication_locale

    I18n.with_locale(locale) do
      @url = edit_participant_invitation_url(token: token, locale: locale)

      mail(
        to:      @user.email,
        subject: t("participant_invitation_mailer.invite.subject",
                   default: "You have been invited to the %{workshop} IMASUS workshop",
                   workshop: workshop.title)
      )
    end
  end
end
