# Public catalogue of installation-configured prompts.
#
# Read surface is the index (`index`) and a sidebar preview drawer
# (`preview`) — there is no standalone show page. Curator actions
# (`edit`, `update`) are guarded by {ApplicationController#require_role}
# and available to admins and facilitators only. Entries are added or retired
# through the installation manifest rather than browser CRUD.
class ChallengesController < ApplicationController
  requires_resource_module :prompts

  before_action :require_curator, only: [ :edit, :update ]
  before_action :set_challenge,   only: [ :preview, :edit, :update ]

  # GET /challenges
  def index
    @prompts_module = resource_module_registry.fetch(:prompts)
    @catalog = Challenge.catalog
    @challenges_by_category = @catalog.categories.each_with_object({}) do |category, memo|
      scoped = Challenge.published.where(category: category.id).ordered.to_a
      memo[category] = scoped if scoped.any?
    end
  end

  # GET /challenges/:code/preview
  #
  # Renders the drawer partial into the layout-level `<turbo-frame id="preview">`
  # slot without the application layout.
  def preview
    render partial: "challenges/preview",
           locals:  { challenge: @challenge },
           layout:  false
  end

  # GET /challenges/:code/edit
  def edit
    @catalog = Challenge.catalog
  end

  # PATCH /challenges/:code
  def update
    @catalog = Challenge.catalog
    if @challenge.update(challenge_params)
      notice = t(".notice", default: "Challenge updated.")
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@challenge),
            partial: "challenges/card",
            locals:  { challenge: @challenge }
          )
        end
        format.html do
          redirect_to challenges_path, notice: notice
        end
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_challenge
    @challenge = Challenge.where("UPPER(code) = ?", params[:code].to_s.upcase).first
    raise ActiveRecord::RecordNotFound, "No Challenge with code #{params[:code].inspect}" unless @challenge
  end

  # Only category and translation fields are mutable. `code` is the stable
  # manifest identifier and cannot be changed through the curator form.
  def challenge_params
    locales = I18n.available_locales.map(&:to_s)
    params.require(:challenge).permit(
      :category,
      question_translations:    locales,
      description_translations: locales
    )
  end

  def require_curator
    require_role :admin, :facilitator
  end
end
