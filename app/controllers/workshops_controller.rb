class WorkshopsController < ApplicationController
  before_action :require_login, only: [ :agenda ]
  before_action :set_workshop, only: [ :show, :agenda ]

  def index
    @workshops = Workshop.ready_for_listing
                         .includes(:participations, projects: :members)
  end

  def show
    @published_projects = @workshop.projects
                                   .published
                                   .includes(:members, :challenge, hero_image_attachment: :blob)
                                   .order(publication_updated_at: :desc, created_at: :desc)

    return unless current_user

    @projects = @workshop.projects
                         .includes(:members, :challenge)
                         .order(created_at: :desc)
    @attending = WorkshopParticipation.exists?(user: current_user, workshop: @workshop)
    @user_project_ids = current_user.projects.where(workshop: @workshop).pluck(:id).to_set
  end

  def agenda
  end

  private

  def set_workshop
    @workshop = Workshop.find_by!(slug: params[:slug])
  end
end
