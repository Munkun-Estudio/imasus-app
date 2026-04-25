# Role-aware home. Renders one of four variants — visitor, participant,
# facilitator, admin — from a single template that delegates to a partial
# matching `current_user&.role`.
class HomeController < ApplicationController
  FEATURED_PROJECT_LIMIT = 6

  def index
    @variant = current_user&.role || "visitor"
    load_visitor_data if @variant == "visitor"
  end

  private

  def load_visitor_data
    @workshops          = Workshop.ordered
    @featured_projects  = Project.published
                                  .order(publication_updated_at: :desc)
                                  .limit(FEATURED_PROJECT_LIMIT)
  end
end
