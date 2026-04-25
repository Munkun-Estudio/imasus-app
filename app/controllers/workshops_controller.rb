class WorkshopsController < ApplicationController
  before_action :require_login, only: [ :agenda, :edit, :update ]
  before_action :set_workshop,  only: [ :show, :agenda, :edit, :update ]
  before_action :require_management, only: [ :edit, :update ]

  def index
    @workshops = Workshop.ready_for_listing
                         .includes(:participations, projects: :members)
  end

  def show
    @published_projects = @workshop.projects
                                   .active
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

  # @note Admins and facilitators participating in this workshop only.
  def edit
  end

  # @note Updates translated, plain, and contact_email fields. Slug is
  #   intentionally not editable from this surface (changing it would
  #   invalidate any URLs already shared).
  def update
    if @workshop.update(workshop_params)
      redirect_to workshop_path(@workshop), notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_workshop
    @workshop = Workshop.find_by!(slug: params[:slug])
  end

  def require_management
    return if @workshop.manageable_by?(current_user)

    redirect_to root_path, alert: t("errors.access_denied",
                                     default: "You are not authorised to view that page.")
  end

  def workshop_params
    params.require(:workshop).permit(
      :location, :starts_on, :ends_on, :contact_email,
      title_translations: {},
      description_translations: {}
    )
  end
end
