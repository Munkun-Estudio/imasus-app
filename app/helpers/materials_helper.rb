module MaterialsHelper
  # Returns the URL for the materials index with `slug` toggled inside `facet`.
  #
  # Preserves every other query parameter (other facets, the search query).
  # When the slug is currently selected it is removed from the facet; when it
  # is absent, it is added. Facets that end up empty are dropped entirely so
  # URLs stay clean.
  #
  # @param facet [String] one of {Tag::FACETS}
  # @param slug [String] the tag slug to toggle
  # @param selected_by_facet [Hash{String => Array<String>}] currently selected slugs grouped by facet
  # @param query [String] current free-text query, passed through untouched
  # @return [String] href for an anchor tag
  def materials_chip_toggle_url(facet, slug, selected_by_facet:, query: nil)
    next_selected = selected_by_facet.each_with_object({}) do |(f, slugs), acc|
      acc[f] = slugs.dup
    end

    current = next_selected[facet] || []
    next_selected[facet] = if current.include?(slug)
      current - [ slug ]
    else
      current + [ slug ]
    end

    params = next_selected.each_with_object({}) do |(f, slugs), acc|
      acc[f] = slugs.join(",") if slugs.any?
    end
    params[:q] = query if query.present?

    materials_path(params)
  end

  # @param facet [String] one of {Tag::FACETS}
  # @param slug [String] tag slug
  # @param selected_by_facet [Hash{String => Array<String>}] currently selected slugs grouped by facet
  # @return [Boolean] whether the chip for this facet/slug is active
  def materials_chip_active?(facet, slug, selected_by_facet:)
    (selected_by_facet[facet] || []).include?(slug)
  end
end
