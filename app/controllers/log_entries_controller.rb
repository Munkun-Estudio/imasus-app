# @api private
class LogEntriesController < ApplicationController
  BATCH_SIZE = 10

  before_action :require_login
  before_action :set_project
  before_action :require_visible, only: [ :index, :media ]
  before_action :require_member, only: [ :new, :create ]

  def index
    scope = @project.log_entries.with_rich_text_body.with_attached_media
                    .includes(:author)

    @page = page_param
    @total_log_entries = scope.count
    @log_entries = scope.limit(BATCH_SIZE).offset((@page - 1) * BATCH_SIZE)
    @next_page = @page + 1 if @page * BATCH_SIZE < @total_log_entries

    if turbo_frame_request? && @page > 1
      render partial: "log_entries/batch",
             locals: { log_entries: @log_entries, page: @page, next_page: @next_page }
    end
  end

  def media
    @log_entry = @project.log_entries.find(params[:id])
    attachment = @log_entry.media.attachments.find(params[:attachment_id])
    raise ActiveRecord::RecordNotFound unless attachment.video?

    render partial: "log_entries/video_player",
           locals: { attachment: attachment },
           layout: false
  end

  def new
    @log_entry = @project.log_entries.build
  end

  def create
    @log_entry = @project.log_entries.build(log_entry_params)
    @log_entry.author = current_user

    if @log_entry.save
      redirect_to project_log_entries_path(@project),
                  notice: t("log_entries.create.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def delete_confirmation
    @log_entry = @project.log_entries.find(params[:id])
    render partial: "log_entries/confirm_delete_modal", locals: { log_entry: @log_entry, project: @project }
  end

  def destroy
    @log_entry = @project.log_entries.find(params[:id])

    unless @log_entry.author == current_user || current_user.admin?
      return redirect_to project_log_entries_path(@project),
                         alert: t("log_entries.errors.forbidden")
    end

    @log_entry.destroy!
    redirect_to project_log_entries_path(@project),
                notice: t("log_entries.destroy.success")
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def require_visible
    return if @project.visible_to?(current_user)

    redirect_to root_path, alert: t("errors.access_denied", default: "You are not authorised to view that page.")
  end

  def require_member
    return if @project.members.include?(current_user)

    redirect_to root_path, alert: t("errors.access_denied", default: "You are not authorised to view that page.")
  end

  def log_entry_params
    params.require(:log_entry).permit(:body, media: [])
  end

  def page_param
    page = params[:page].to_i
    page.positive? ? page : 1
  end
end
