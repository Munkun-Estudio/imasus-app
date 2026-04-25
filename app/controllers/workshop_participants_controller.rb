# Per-workshop participants list and remove action. Authorisation is
# `Workshop#manageable_by?(current_user)` — admins, plus facilitators
# with a {WorkshopParticipation} on this workshop.
#
# Removal destroys the {WorkshopParticipation} only. The {User} record
# and any existing {ProjectMembership}s remain — removing someone from a
# workshop is an organisational action, not a content action. Project
# moderation lives in {ProjectsController#disable}.
class WorkshopParticipantsController < ApplicationController
  before_action :require_login
  before_action :set_workshop
  before_action :require_management

  def index
    @participations = @workshop.participations
                               .includes(:user)
                               .order("users.name")
                               .references(:users)
  end

  # @note Refuses to remove the current user (you can't kick yourself)
  #   and refuses to remove an admin user.
  def destroy
    user = User.find(params[:user_id])
    return redirect_to_index_with_alert if forbidden_target?(user)

    @workshop.participations.where(user: user).destroy_all
    redirect_to workshop_participants_path(@workshop), notice: t(".success", name: user.name)
  end

  private

  def set_workshop
    @workshop = Workshop.find_by!(slug: params[:workshop_slug])
  end

  def require_management
    return if @workshop.manageable_by?(current_user)

    redirect_to root_path, alert: t("errors.access_denied",
                                     default: "You are not authorised to view that page.")
  end

  def forbidden_target?(user)
    user.id == current_user.id || user.admin?
  end

  def redirect_to_index_with_alert
    redirect_to workshop_participants_path(@workshop),
                alert: t(".forbidden", default: "That participant cannot be removed.")
  end
end
