# Handles the workflow that turns a draft project into a public, published
# project — and the subsequent edits to that published content. The slug is
# assigned on first publish and never changes afterwards.
class ProjectPublicationsController < ApplicationController
  before_action :require_login
  before_action :set_project

  # @note Requires member or admin; project must be draft.
  def new
    require_publishable
  end

  # @note Sets status "published", stamps +publication_updated_at+, generates slug.
  #   Redirects to public page on success; re-renders new on failure.
  def create
    return unless require_publishable

    @project.assign_attributes(publication_params)
    @project.status = "published"
    @project.publication_updated_at = Time.current

    if @project.save
      redirect_to published_project_path(slug: @project.slug),
                  notice: t("project_publications.create.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # @note Requires member or admin; project must be published.
  def edit
    require_republishable
  end

  # @note Updates publication fields and refreshes +publication_updated_at+. Slug is immutable.
  def update
    return unless require_republishable

    @project.assign_attributes(publication_params)
    @project.publication_updated_at = Time.current

    if @project.save
      redirect_to published_project_path(slug: @project.slug),
                  notice: t("project_publications.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def require_publishable
    return true if @project.publishable_by?(current_user)

    redirect_to project_path(@project),
                alert: t("project_publications.errors.forbidden")
    false
  end

  def require_republishable
    return true if @project.republishable_by?(current_user)

    redirect_to project_path(@project),
                alert: t("project_publications.errors.forbidden")
    false
  end

  def publication_params
    params.require(:project).permit(:hero_image, :process_summary)
  end
end
