class WorkshopEmailBroadcastMailer < ApplicationMailer
  def broadcast(broadcast, recipient)
    @broadcast = broadcast
    @recipient = recipient
    @workshop = broadcast.workshop

    I18n.with_locale(recipient.preferred_locale.presence || @workshop.communication_locale) do
      mail(to: recipient.email, subject: broadcast.subject)
    end
  end

  def test_message(sender:, workshop:, subject:, body_html:, body_text:, recipient:)
    @sender = sender
    @workshop = workshop
    @body_html = body_html
    @body_text = body_text

    I18n.with_locale(recipient.preferred_locale.presence || workshop.communication_locale) do
      mail(to: recipient.email, subject: subject)
    end
  end
end
