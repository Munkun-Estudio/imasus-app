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
      recipient: current_user
    ).deliver_later

    @preview_mode = true
    flash.now[:notice] = t(".notice",
                           default: "Sent a test email to %{email}.",
                           email: current_user.email)
    render :new
  end

  private

  def set_workshop
    @workshop = Workshop.find_by!(slug: params[:workshop_slug] || params[:workshop_id] || params[:slug])
  end

  def build_draft
    WorkshopEmailDraft.new(
      workshop: @workshop,
      sender: current_user,
      audience: workshop_email_params[:audience],
      subject: workshop_email_params[:subject],
      body: workshop_email_params[:body]
    )
  end

  def workshop_email_params
    params.fetch(:workshop_email, {}).permit(:audience, :subject, :body)
  end

  def load_recent_broadcasts
    @recent_broadcasts = @workshop.workshop_email_broadcasts.includes(:sender).recent_first.limit(5)
  end

  def render_new_with_errors
    @preview_mode = false
    render :new, status: :unprocessable_content
  end
end
