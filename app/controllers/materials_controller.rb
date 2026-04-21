# Public index of the IMASUS sustainable materials catalogue.
#
# Presents a chip-filter rail (OR within a facet, AND across facets), a
# free-text search over the trade name and the current-locale description,
# and a grid of material cards. Unknown facets and unknown chip slugs are
# silently ignored so shareable URLs stay robust as the vocabulary evolves.
class MaterialsController < ApplicationController
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

  private

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
end
