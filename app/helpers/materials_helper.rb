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

  # Renders a translatable material prose field for the detail page.
  #
  # Pipeline: locale-fallback read → `simple_format` (paragraphs) →
  # `sanitize` allow-list restricted to `p`/`br` → `glossary_highlight`
  # (wraps known glossary terms as popover triggers). Returns `nil` when
  # the field has no value in the current locale or the base locale, so
  # callers can hide the entire section.
  #
  # @param material [Material]
  # @param attribute [Symbol] one of {Material::TRANSLATED_ATTRIBUTES}
  # @return [ActiveSupport::SafeBuffer, nil]
  def material_prose(material, attribute)
    value = material.public_send(:"#{attribute}_in", I18n.locale) ||
            material.public_send(:"#{attribute}_in", Material::BASE_LOCALE)
    return nil if value.to_s.strip.empty?

    glossary_highlight(sanitize(simple_format(value), tags: %w[p br]))
  end

  # Builds the ordered list of media items that populates the detail-page
  # gallery.
  #
  # Priority — first item becomes the default view in the main slot:
  #
  #   1. video_asset (if attached)
  #   2. macro_asset (if attached)
  #   3. microscopies, in stored position order
  #
  # Each hash carries the rendering information the view needs so the
  # template can stay declarative:
  #
  #   { key:, kind:, asset:, alt:, micrograph_index: }
  #
  # `key` is a stable, unique identifier used to match main-slot media
  # with their thumbnail via `data-media-key`. Assets without an attached
  # file are skipped.
  #
  # @param material [Material]
  # @return [Array<Hash>]
  def material_gallery_items(material)
    items = []

    video = material.video_asset
    if video&.file&.attached?
      items << {
        key:   "video",
        kind:  "video",
        asset: video,
        alt:   t("materials.show.video_thumb_label", name: material.trade_name)
      }
    end

    macro = material.macro_asset
    if macro&.file&.attached?
      items << {
        key:   "macro",
        kind:  "macro",
        asset: macro,
        alt:   t("materials.show.macro_alt", name: material.trade_name)
      }
    end

    material.microscopies.each_with_index do |micro, index|
      next unless micro.file.attached?
      items << {
        key:              "micro-#{index}",
        kind:             "microscopy",
        asset:            micro,
        alt:              t("materials.show.micrograph_alt", name: material.trade_name, index: index + 1),
        micrograph_index: index + 1
      }
    end

    items
  end

  # Builds the meta-description content for a material detail page.
  #
  # Uses the locale-fallback `description`, strips any HTML, collapses
  # whitespace, and truncates to 155 characters — the soft ceiling most
  # search engines respect before eliding.
  #
  # @param material [Material]
  # @return [String, nil]
  def material_meta_description(material)
    value = material.description_in(I18n.locale) ||
            material.description_in(Material::BASE_LOCALE)
    return nil if value.to_s.strip.empty?

    strip_tags(value).squish.truncate(155, separator: " ")
  end
end
