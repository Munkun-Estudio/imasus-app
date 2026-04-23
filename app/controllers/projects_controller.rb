class ProjectsController < ApplicationController
  before_action :require_login
  before_action :set_project,        only: [ :show, :edit, :update, :destroy ]
  before_action :require_visible,    only: [ :show ]
  before_action :require_editable,   only: [ :edit, :update ]
  before_action :require_destroyable, only: [ :destroy ]

  # @note Lists current user's projects; admin/facilitator see all.
  def index
    @projects = if current_user.admin? || current_user.facilitator?
      Project.includes(:workshop, :members).order(created_at: :desc)
    else
      current_user.projects.includes(:workshop).order(created_at: :desc)
    end
  end

  # @note Requires +workshop_id+ param and workshop participation.
  def new
    @workshop = find_accessible_workshop
    return unless @workshop

    @project = @workshop.projects.new(language: @workshop.communication_locale)
  end

  # @note Creates project and creator membership in a single transaction.
  def create
    @workshop = find_accessible_workshop
    return unless @workshop

    @project = @workshop.projects.new(project_params)

    Project.transaction do
      @project.save!
      @project.memberships.create!(user: current_user)
    end

    redirect_to @project, notice: t("projects.create.success")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  # @note Visible to members, facilitators, and admins.
  def show
  end

  def edit
  end

  # @note Forbidden for facilitators; re-renders edit on failure.
  def update
    if @project.update(project_params)
      redirect_to @project, notice: t("projects.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # @note Allowed for members and admins only; cascades memberships.
  def destroy
    @project.destroy!
    redirect_to projects_path, notice: t("projects.destroy.success")
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:title, :description, :challenge_id, :language, :workshop_id)
  end

  def find_accessible_workshop
    if params[:workshop_id].blank? && params.dig(:project, :workshop_id).blank?
      redirect_to workshops_path and return nil
    end

    workshop_id = params[:workshop_id] || params.dig(:project, :workshop_id)
    workshop = Workshop.find_by(id: workshop_id)

    unless workshop && WorkshopParticipation.exists?(user: current_user, workshop: workshop)
      redirect_to workshop ? workshop_path(workshop) : workshops_path, alert: t("projects.errors.not_a_participant")
      return nil
    end

    workshop
  end

  def require_visible
    unless @project.visible_to?(current_user)
      redirect_to projects_path, alert: t("projects.errors.not_visible")
    end
  end

  def require_editable
    unless @project.editable_by?(current_user)
      redirect_to project_path(@project), alert: t("projects.errors.not_editable")
    end
  end

  def require_destroyable
    unless @project.editable_by?(current_user)
      redirect_to project_path(@project), alert: t("projects.errors.not_editable")
    end
  end
end
