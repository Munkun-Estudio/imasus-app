# Public, multilingual glossary of IMASUS workshop vocabulary.
#
# Read actions (`index`, `show`) are open to any visitor. Write actions
# (`new`, `create`, `edit`, `update`, `destroy`) are guarded by
# {ApplicationController#require_role} and available to admins and
# facilitators only.
#
# Category and letter filters on the index come from UI chrome that only
# exposes known values, so unknown filters degrade to the full list rather
# than returning an error.
class GlossaryTermsController < ApplicationController
  before_action :require_curator, only: [ :new, :create, :edit, :update, :destroy, :delete_confirmation ]
  before_action :set_glossary_term, only: [ :show, :edit, :update, :destroy, :delete_confirmation, :popover ]

  # GET /glossary
  # GET /glossary?category=methodology
  def index
    scope = GlossaryTerm.all

    if GlossaryTerm::CATEGORIES.include?(params[:category])
      @active_category = params[:category]
      scope = scope.where(category: @active_category)
    end

    @terms = scope.to_a.sort_by { |term| (term.term_in(GlossaryTerm::BASE_LOCALE) || "").downcase }
    @terms_by_letter = @terms.group_by { |term| first_letter(term) }
    @available_letters = @terms_by_letter.keys.to_set
    @available_categories = GlossaryTerm.distinct.pluck(:category) & GlossaryTerm::CATEGORIES
  end

  # GET /glossary/:slug
  def show
  end

  # GET /glossary/new
  def new
    @glossary_term = GlossaryTerm.new
  end

  # POST /glossary
  def create
    @glossary_term = GlossaryTerm.new(glossary_term_params)

    if @glossary_term.save
      redirect_to glossary_term_path(@glossary_term.slug),
                  notice: t(".notice", default: "Glossary term created.")
    else
      render :new, status: :unprocessable_content
    end
  end

  # GET /glossary/:slug/edit
  def edit
  end

  # PATCH /glossary/:slug
  def update
    if @glossary_term.update(glossary_term_params)
      notice = t(".notice", default: "Glossary term updated.")
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@glossary_term),
            partial: "glossary_terms/term_row",
            locals: { term: @glossary_term }
          )
        end
        format.html do
          redirect_to glossary_term_path(@glossary_term.slug), notice: notice
        end
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  # GET /glossary/:slug/popover
  #
  # Returns a small HTML fragment with the term, short definition, and a link
  # to the full glossary page. Intended for XHR fetch by the Stimulus popover
  # controller — rendered without the application layout.
  def popover
    render partial: "glossary_terms/popover_content",
           locals:  { glossary_term: @glossary_term },
           layout:  false
  end

  # GET /glossary/:slug/delete_confirmation
  #
  # Returns the "Are you sure?" dialog as a turbo-frame targeting the page's
  # modal slot. This keeps deletion an accessible, styled interaction rather
  # than the browser-native `confirm()` dialog.
  def delete_confirmation
    render partial: "glossary_terms/confirm_delete_modal",
           locals:  { glossary_term: @glossary_term }
  end

  # DELETE /glossary/:slug
  def destroy
    @glossary_term.destroy
    notice = t(".notice", default: "Glossary term deleted.")
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: turbo_stream.remove(helpers.dom_id(@glossary_term))
      end
      format.html do
        redirect_to glossary_terms_path, notice: notice
      end
    end
  end

  private

  def set_glossary_term
    @glossary_term = GlossaryTerm.find_by!(slug: params[:slug])
  end

  def glossary_term_params
    locales = I18n.available_locales.map(&:to_s)
    permitted = params.require(:glossary_term).permit(
      :slug,
      :category,
      term_translations:       locales,
      definition_translations: locales,
      examples_translations:   locales
    )

    if permitted[:examples_translations].present?
      permitted[:examples_translations] = permitted[:examples_translations].transform_values do |value|
        value.to_s.lines.map(&:strip).reject(&:blank?)
      end
    end

    permitted
  end

  def require_curator
    require_role :admin, :facilitator
  end

  def first_letter(term)
    value = term.term_in(GlossaryTerm::BASE_LOCALE).to_s
    letter = value[0, 1].upcase
    ("A".."Z").cover?(letter) ? letter : "#"
  end
end
