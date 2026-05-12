class WorkshopEmailBroadcastMailer < ApplicationMailer
  def broadcast(broadcast, recipient)
    @broadcast = broadcast
    @recipient = recipient
    @workshop = broadcast.workshop
    attach_pdf(broadcast.pdf_attachment) if broadcast.pdf_attachment.attached?

    I18n.with_locale(recipient.preferred_locale.presence || @workshop.communication_locale) do
      mail(to: recipient.email, subject: broadcast.subject)
    end
  end

  def test_message(sender:, workshop:, subject:, body_html:, body_text:, recipient:, pdf_attachment_blob: nil)
    @sender = sender
    @workshop = workshop
    @body_html = body_html
    @body_text = body_text
    attach_pdf(pdf_attachment_blob) if pdf_attachment_blob.present?

    I18n.with_locale(recipient.preferred_locale.presence || workshop.communication_locale) do
      mail(to: recipient.email, subject: subject)
    end
  end

  private

  def attach_pdf(blob_or_attachment)
    blob = blob_or_attachment.respond_to?(:blob) ? blob_or_attachment.blob : blob_or_attachment
    return if blob.blank?

    attachments[blob.filename.to_s] = {
      mime_type: blob.content_type,
      content: blob.download
    }
  end
end
