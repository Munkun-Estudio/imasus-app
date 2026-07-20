# Public index of the installation's materials catalogue.
#
# Presents a chip-filter rail (OR within a facet, AND across facets), a
# free-text search over the trade name and the current-locale description,
# and a grid of material cards. Unknown facets and unknown chip slugs are
# silently ignored so shareable URLs stay robust as the vocabulary evolves.
class MaterialsController < ApplicationController
  requires_resource_module :library

  BATCH_SIZE = 12

  before_action :require_curator, only: [ :edit, :update ]
  before_action :set_library_resource, only: [ :show, :media, :preview, :edit, :update ]

  # GET /materials
  # GET /materials?origin_type=plants,fungi&application=clothing&q=cypress
  def index
    return generic_index if generic_presentation?

    @selected_slugs_by_facet = selected_slugs_by_facet
    @selected_tag_ids_by_facet = resolve_selected_tag_ids(@selected_slugs_by_facet)
    @query = params[:q].to_s.strip

    scope = Material
              .includes(assets: { file_attachment: :blob })
              .order(:position)
    scope = apply_facet_filters(scope, @selected_tag_ids_by_facet)
    scope = apply_search(scope, @query)

    @page = page_param
    @total_materials = scope.count
    @materials = scope.limit(BATCH_SIZE).offset((@page - 1) * BATCH_SIZE).to_a
    @tags_by_facet = Tag.all.group_by(&:facet)
    @chip_counts = chip_counts_for(scope)
    @any_filters_active = @selected_tag_ids_by_facet.any? || @query.present?
    @next_page = @page + 1 if @page * BATCH_SIZE < @total_materials

    if turbo_frame_request? && @page > 1
      render partial: "materials/batch",
             locals: { materials: @materials, page: @page, next_page: @next_page }
    end
  end

  # GET /materials/:slug
  #
  # Renders the full editorial detail page: macro hero, header with
  # supplier and tag chips, prose sections (localised, with glossary-term
  # highlighting), and a micrograph gallery when microscopies are attached.
  # Unknown slug raises `ActiveRecord::RecordNotFound` via `set_material`
  # and surfaces as a 404.
  def show
    render "library_items/show" if generic_presentation?
  end

  # GET /materials/:slug/media?key=macro
  #
  # Deferred gallery endpoint used by thumbnail selection and poster-first
  # video playback. The initial detail page keeps full-size offscreen media
  # and video blob URLs out of the DOM; this action returns one requested
  # media item after user intent.
  def media
    if generic_presentation?
      item = helpers.library_gallery_items(@library_item).find { |candidate| candidate[:key] == params[:key].to_s }
      raise ActiveRecord::RecordNotFound unless item

      render partial: "library_items/gallery_media",
             locals: { item:, library_item: @library_item, deferred: false },
             layout: false
      return
    end

    item = helpers.material_gallery_items(@material).find { |candidate| candidate[:key] == params[:key].to_s }
    raise ActiveRecord::RecordNotFound unless item

    render partial: "materials/gallery_media",
           locals: { item: item, material: @material, deferred: false },
           layout: false
  end

  # GET /materials/:slug/preview
  #
  # Returns the preview-sidebar partial as a bare HTML fragment intended
  # for the layout-level `<turbo-frame id="preview">` slot. No application
  # layout — same pattern as {GlossaryTermsController#popover}.
  def preview
    if generic_presentation?
      render partial: "library_items/preview",
             locals: { library_item: @library_item },
             layout: false
      return
    end

    render partial: "materials/preview",
           locals:  { material: @material },
           layout:  false
  end

  # GET /materials/:slug/edit
  def edit
    raise ActiveRecord::RecordNotFound if generic_presentation?

    @tags_by_facet = Tag.all.group_by(&:facet)
  end

  # PATCH /materials/:slug
  def update
    raise ActiveRecord::RecordNotFound if generic_presentation?

    @tags_by_facet = Tag.all.group_by(&:facet)

    if @material.update(material_params)
      apply_selected_tags if tag_selection_submitted?
      redirect_to material_path(@material), notice: t(".notice", default: "Material updated.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_library_resource
    if generic_presentation?
      @library_item = LibraryItem
                        .includes(
                          :taxonomy_terms,
                          assets: [
                            { file_attachment: :blob },
                            { poster_attachment: :blob }
                          ]
                        )
                        .find_by!(slug: params[:slug])
    else
      @material = Material
                    .includes(
                      :tags,
                      assets: [
                        { file_attachment: :blob },
                        { poster_attachment: :blob }
                      ]
                    )
                    .find_by!(slug: params[:slug])
    end
  end

  def generic_index
    @query = params[:q].to_s.strip
    @selected_taxonomies = selected_generic_taxonomies
    @selected_item_types = Array(params[:type].to_s.split(",")).reject(&:blank?)

    scope = LibraryItem.published
                       .includes(assets: { file_attachment: :blob })
                       .order(:position, :slug)
    scope = scope.where(item_type: @selected_item_types) if @selected_item_types.any?
    scope = apply_generic_filters(scope, @selected_taxonomies)
    scope = apply_generic_search(scope, @query)

    @page = page_param
    @total_library_items = scope.count
    @library_items = scope.limit(BATCH_SIZE).offset((@page - 1) * BATCH_SIZE).to_a
    @filter_taxonomies = LibraryCatalog.current.taxonomies.select(&:filter)
    @terms_by_taxonomy = LibraryTaxonomyTerm.published.order(:position).group_by(&:taxonomy_key)
    @generic_chip_counts = generic_chip_counts_for(scope)
    @any_filters_active = @selected_taxonomies.any? || @selected_item_types.any? || @query.present?
    @next_page = @page + 1 if @page * BATCH_SIZE < @total_library_items

    if turbo_frame_request? && @page > 1
      render partial: "library_items/batch",
             locals: { library_items: @library_items, page: @page, next_page: @next_page }
    else
      render "library_items/index"
    end
  end

  def generic_presentation?
    ActiveModel::Type::Boolean.new.cast(params[:generic]) ||
      LibraryCatalog.current.item_type_ids != [ "material" ]
  end

  def selected_generic_taxonomies
    LibraryCatalog.current.taxonomies.select(&:filter).each_with_object({}) do |taxonomy, selected|
      slugs = params[taxonomy.id].to_s.split(",").map(&:strip).reject(&:blank?)
      selected[taxonomy.id] = slugs if slugs.any?
    end
  end

  def apply_generic_filters(scope, selected)
    selected.each do |taxonomy_key, slugs|
      term_ids = LibraryTaxonomyTerm.where(taxonomy_key:, slug: slugs).select(:id)
      scope = scope.where(
        id: LibraryItemTagging.where(library_taxonomy_term_id: term_ids).select(:library_item_id)
      )
    end
    scope
  end

  def apply_generic_search(scope, query)
    return scope if query.blank?

    needle = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    locale = I18n.locale.to_s
    fallback = Rails.configuration.site.locales.fallback
    scope.where(
      "library_items.title_translations->>:locale ILIKE :needle " \
      "OR library_items.title_translations->>:fallback ILIKE :needle " \
      "OR library_items.summary_translations->>:locale ILIKE :needle " \
      "OR library_items.summary_translations->>:fallback ILIKE :needle",
      needle:, locale:, fallback:
    )
  end

  def generic_chip_counts_for(scope)
    LibraryItemTagging.where(library_item_id: scope.reselect(:id))
                      .group(:library_taxonomy_term_id).count
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

  def page_param
    page = params[:page].to_i
    page.positive? ? page : 1
  end

  def chip_counts_for(scope)
    material_ids = scope.reselect(:id)

    MaterialTagging.where(material_id: material_ids).group(:tag_id).count
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
