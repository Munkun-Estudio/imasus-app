class ProjectMembershipsController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :require_member_or_admin

  def new
    @eligible = @project.workshop.participants.where.not(id: @project.member_ids)
    render partial: "project_memberships/drawer", layout: false
  end

  # @note Adds a workshop participant as a project member.
  def create
    user = User.find_by(id: params.dig(:project_membership, :user_id))

    unless user && WorkshopParticipation.exists?(user: user, workshop: @project.workshop)
      return render_error(t("project_memberships.errors.not_a_participant"))
    end

    membership = @project.memberships.build(user: user)
    if membership.save
      redirect_to @project, notice: t("project_memberships.create.success", name: user.name)
    else
      render_error(membership.errors.full_messages.first)
    end
  end

  # @note Allows self-removal and admin removal; last member triggers project destroy.
  def destroy
    membership = @project.memberships.find(params[:id])

    unless membership.user == current_user || current_user.admin?
      return redirect_to @project, alert: t("project_memberships.errors.forbidden")
    end

    leaving_self = membership.user == current_user
    membership.destroy!

    if Project.exists?(@project.id)
      if leaving_self
        redirect_to projects_path, notice: t("project_memberships.destroy.left")
      else
        redirect_to @project, notice: t("project_memberships.destroy.removed")
      end
    else
      redirect_to projects_path, notice: t("project_memberships.destroy.project_deleted")
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def require_member_or_admin
    return if current_user.admin?

    unless @project.members.include?(current_user)
      redirect_to @project, alert: t("project_memberships.errors.forbidden")
    end
  end

  def render_error(message)
    flash.now[:alert] = message
    render "projects/show", status: :unprocessable_entity
  end
end
