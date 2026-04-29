class Admin::WorkshopEmailsController < ApplicationController
  before_action -> { require_role :admin }
  before_action :set_workshop
  before_action :load_recent_broadcasts, only: [ :new ]

  def index
    @broadcasts = @workshop.workshop_email_broadcasts.includes(:sender).recent_first
  end

  def new
    @draft = build_draft
  end

  def create
    @draft = build_draft

    if params[:edit_mode] == "1"
      @preview_mode = false
      render :new
    elsif params[:confirm_send] == "1"
      return render_new_with_errors unless @draft.valid?(:delivery)

      broadcast = SendWorkshopEmailBroadcast.call(draft: @draft)
      redirect_to admin_workshop_emails_path(@workshop),
                  notice: t(".notice",
                            default: "Sent \"%{subject}\" to %{count} %{audience} in %{workshop}.",
                            subject: broadcast.subject,
                            count: broadcast.recipient_count,
                            audience: broadcast.audience_label.downcase,
                            workshop: @workshop.title)
    else
      return render_new_with_errors unless @draft.valid?(:delivery)

      @preview_mode = true
      render :new
    end
  end

  def send_test
    @draft = build_draft
    return render_new_with_errors unless @draft.valid?

    WorkshopEmailBroadcastMailer.test_message(
      sender: current_user,
      workshop: @workshop,
      subject: @draft.normalized_subject,
      body_html: @draft.normalized_html,
      body_text: @draft.normalized_text,
      recipient: current_user,
      pdf_attachment_blob: @draft.pdf_attachment_blob
    ).deliver_later

    redirect_to new_admin_workshop_email_path(@workshop, workshop_email: draft_attributes),
                notice: t(".notice",
                          default: "Sent a test email to %{email}.",
                          email: current_user.email)
  end

  private

  def set_workshop
    @workshop = Workshop.find_by!(slug: params[:workshop_slug] || params[:workshop_id] || params[:slug])
  end

  def build_draft
    WorkshopEmailDraft.new(
      workshop: @workshop,
      sender: current_user,
      audience: draft_attributes[:audience],
      subject: draft_attributes[:subject],
      body: draft_attributes[:body],
      pdf_attachment_signed_id: draft_attributes[:pdf_attachment_signed_id],
      pdf_attachment_blob: resolved_pdf_attachment_blob
    )
  end

  def draft_attributes
    attrs = params.fetch(:workshop_email, {}).permit(:audience, :subject, :body, :pdf_attachment_signed_id).to_h
    attrs["pdf_attachment_signed_id"] =
      if remove_pdf_attachment?
        nil
      else
        resolved_pdf_attachment_blob&.signed_id || attrs["pdf_attachment_signed_id"]
      end
    attrs
  end

  def load_recent_broadcasts
    @recent_broadcasts = @workshop.workshop_email_broadcasts.includes(:sender).recent_first.limit(5)
  end

  def render_new_with_errors
    @preview_mode = false
    render :new, status: :unprocessable_content
  end

  def resolved_pdf_attachment_blob
    return @resolved_pdf_attachment_blob if defined?(@resolved_pdf_attachment_blob)

    @resolved_pdf_attachment_blob =
      if remove_pdf_attachment?
        nil
      elsif uploaded_pdf_attachment.present?
        ActiveStorage::Blob.create_and_upload!(
          io: uploaded_pdf_attachment.tempfile,
          filename: uploaded_pdf_attachment.original_filename,
          content_type: uploaded_pdf_attachment.content_type
        )
      elsif params.dig(:workshop_email, :pdf_attachment_signed_id).present?
        ActiveStorage::Blob.find_signed(params.dig(:workshop_email, :pdf_attachment_signed_id))
      end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    @resolved_pdf_attachment_blob = nil
  end

  def uploaded_pdf_attachment
    params.dig(:workshop_email, :pdf_attachment)
  end

  def remove_pdf_attachment?
    params.dig(:workshop_email, :remove_pdf_attachment) == "1"
  end
end
