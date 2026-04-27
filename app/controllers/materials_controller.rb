# Public index of the IMASUS sustainable materials catalogue.
#
# Presents a chip-filter rail (OR within a facet, AND across facets), a
# free-text search over the trade name and the current-locale description,
# and a grid of material cards. Unknown facets and unknown chip slugs are
# silently ignored so shareable URLs stay robust as the vocabulary evolves.
class MaterialsController < ApplicationController
  before_action :require_curator, only: [ :edit, :update ]
  before_action :set_material, only: [ :show, :preview, :edit, :update ]

  # GET /materials
  # GET /materials?origin_type=plants,fungi&application=clothing&q=cypress
  def index
    @selected_slugs_by_facet = selected_slugs_by_facet
    @selected_tag_ids_by_facet = resolve_selected_tag_ids(@selected_slugs_by_facet)
    @query = params[:q].to_s.strip

    scope = Material
              .includes(assets: { file_attachment: :blob })
              .order(:position)
    scope = apply_facet_filters(scope, @selected_tag_ids_by_facet)
    scope = apply_search(scope, @query)

    @materials = scope.to_a
    @tags_by_facet = Tag.all.group_by(&:facet)
    @chip_counts = chip_counts_for(@materials)
    @any_filters_active = @selected_tag_ids_by_facet.any? || @query.present?
  end

  # GET /materials/:slug
  #
  # Renders the full editorial detail page: macro hero, header with
  # supplier and tag chips, prose sections (localised, with glossary-term
  # highlighting), and a micrograph gallery when microscopies are attached.
  # Unknown slug raises `ActiveRecord::RecordNotFound` via `set_material`
  # and surfaces as a 404.
  def show
  end

  # GET /materials/:slug/preview
  #
  # Returns the preview-sidebar partial as a bare HTML fragment intended
  # for the layout-level `<turbo-frame id="preview">` slot. No application
  # layout — same pattern as {GlossaryTermsController#popover}.
  def preview
    render partial: "materials/preview",
           locals:  { material: @material },
           layout:  false
  end

  # GET /materials/:slug/edit
  def edit
    @tags_by_facet = Tag.all.group_by(&:facet)
  end

  # PATCH /materials/:slug
  def update
    @tags_by_facet = Tag.all.group_by(&:facet)

    if @material.update(material_params)
      apply_selected_tags if tag_selection_submitted?
      redirect_to material_path(@material), notice: t(".notice", default: "Material updated.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_material
    @material = Material
                  .includes(assets: { file_attachment: :blob }, tags: {})
                  .find_by!(slug: params[:slug])
  end

  def selected_slugs_by_facet
    Tag::FACETS.each_with_object({}) do |facet, acc|
      raw = params[facet].to_s
      next if raw.blank?

      slugs = raw.split(",").map(&:strip).reject(&:blank?)
      acc[facet] = slugs unless slugs.empty?
    end
  end

  def resolve_selected_tag_ids(slugs_by_facet)
    slugs_by_facet.each_with_object({}) do |(facet, slugs), acc|
      ids = Tag.where(facet: facet, slug: slugs).pluck(:id)
      acc[facet] = ids if ids.any?
    end
  end

  def apply_facet_filters(scope, tag_ids_by_facet)
    tag_ids_by_facet.each_value do |ids|
      scope = scope.where(
        id: MaterialTagging.where(tag_id: ids).select(:material_id)
      )
    end
    scope
  end

  def apply_search(scope, query)
    return scope if query.blank?

    needle = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    locale_key = I18n.locale.to_s
    scope.where(
      "trade_name ILIKE :needle OR description_translations->>:locale ILIKE :needle",
      needle: needle, locale: locale_key
    )
  end

  def chip_counts_for(materials)
    return {} if materials.empty?

    MaterialTagging.where(material_id: materials.map(&:id)).group(:tag_id).count
  end

  def material_params
    locales = I18n.available_locales.map(&:to_s)
    params.require(:material).permit(
      :trade_name,
      :supplier_name,
      :supplier_url,
      :material_of_origin,
      :availability_status,
      description_translations:            locales,
      sensorial_qualities_translations:    locales,
      what_problem_it_solves_translations: locales,
      interesting_properties_translations: locales,
      structure_translations:              locales
    )
  end

  def selected_tag_ids
    params.fetch(:material, {})
          .fetch(:tag_ids, [])
          .reject(&:blank?)
          .map(&:to_i)
  end

  def apply_selected_tags
    @material.taggings.where.not(tag_id: selected_tag_ids).destroy_all
    (selected_tag_ids - @material.tags.pluck(:id)).each do |tag_id|
      @material.taggings.create!(tag_id: tag_id)
    end
  end

  def tag_selection_submitted?
    params.fetch(:material, {}).key?(:tag_ids)
  end

  def require_curator
    require_role :admin, :facilitator
  end
end
