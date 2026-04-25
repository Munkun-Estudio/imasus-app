# Public, unauthenticated view of a published project. The slug is the
# public URL param; draft projects and unknown slugs return 404.
class PublishedProjectsController < ApplicationController
  layout "public"

  # @note Public; no login required. 404 on unknown slug or draft project.
  def show
    @project = Project.published
                      .includes(:members, :challenge, :workshop)
                      .find_by!(slug: params[:slug])
  end
end
