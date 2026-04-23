# @api private
class LogEntriesController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :require_visible, only: :index
  before_action :require_member, only: [ :new, :create ]

  def index
    @log_entries = @project.log_entries.with_rich_text_body.with_attached_media
                           .includes(:author)
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
end
