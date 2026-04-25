# Role-aware home. Renders one of four variants — visitor, participant,
# facilitator, admin — from a single template that delegates to a partial
# matching `current_user&.role`.
class HomeController < ApplicationController
  FEATURED_PROJECT_LIMIT = 6

  # @note Picks a variant based on +current_user&.role+. The string lands
  #   in +@variant+ and the matching `_<variant>.html.erb` partial is
  #   rendered by `index.html.erb`.
  def index
    @variant = current_user&.role || "visitor"

    case @variant
    when "visitor"     then load_visitor_data
    when "participant" then load_participant_data
    when "facilitator" then load_facilitator_data
    when "admin"       then load_admin_data
    end
  end

  private

  def load_visitor_data
    @workshops          = Workshop.ordered
    @featured_projects  = Project.published
                                  .includes(:workshop)
                                  .order(publication_updated_at: :desc)
                                  .limit(FEATURED_PROJECT_LIMIT)
  end

  def load_participant_data
    @projects = current_user.projects
                            .includes(:workshop, :challenge, :members, :log_entries)
                            .order(updated_at: :desc)
    @workshops = current_user.workshops
  end

  def load_facilitator_data
    @workshops = current_user.workshops.includes(:participations, :projects)
  end

  def load_admin_data
    @workshops = Workshop.ordered.includes(:participations, :projects)
  end
end
