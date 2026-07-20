require "uri"

module LibraryItemsHelper
  def library_module_label
    resource_module_label(resource_module_registry.fetch(:library))
  end

  def library_item_type_label(item_or_type)
    type = item_or_type.respond_to?(:item_type_definition) ? item_or_type.item_type_definition : item_or_type
    type&.label(locale: I18n.locale, locales: Rails.configuration.site.locales)
  end

  def library_taxonomy_label(taxonomy)
    taxonomy.label(locale: I18n.locale, locales: Rails.configuration.site.locales)
  end

  def library_term_label(term)
    term.name_in(I18n.locale).presence || term.name_in(LibraryTaxonomyTerm.base_locale)
  end

  def library_field_label(field)
    field.label(locale: I18n.locale, locales: Rails.configuration.site.locales)
  end

  def library_card_fields(item)
    item.item_type_definition.fields.select(&:card).filter_map do |field|
      value = item.field_value(field.id)
      [ field, value ] if value.present? || value == false
    end
  end

  def library_detail_fields(item, display:)
    item.item_type_definition.fields.select { |field| field.display == display }.filter_map do |field|
      value = item.field_value(field.id)
      [ field, value ] if value.present? || value == false
    end
  end

  def render_library_field(field, value, compact: false)
    values = field.multiple? ? Array(value) : [ value ]
    rendered = values.map { |entry| render_library_scalar(field, entry, compact:) }
    return rendered.first unless field.multiple?

    content_tag(:ul, class: compact ? "flex flex-wrap gap-1.5" : "list-disc space-y-1 pl-5") do
      safe_join(rendered.map { |entry| content_tag(:li, entry) })
    end
  end

  def render_library_scalar(field, value, compact:)
    case field.kind
    when "text"
      library_safe_text(value, compact:)
    when "url"
      library_safe_link(value, value)
    when "boolean"
      t(value ? "library_items.values.yes" : "library_items.values.no")
    when "select"
      labels = field.options[value.to_s]
      Rails.configuration.site.locales.fallback_chain(I18n.locale)
           .filter_map { |locale| labels&.fetch(locale, nil) }.first || value.to_s.humanize
    else
      value.to_s
    end
  end

  def library_safe_text(value, compact: false)
    plain = strip_embedded_data_uri_references(value)
    return plain if compact

    rendered = sanitize(simple_format(plain), tags: %w[p br])
    return rendered unless resource_module_registry.enabled?(:glossary)

    glossary_highlight(rendered)
  end

  def library_safe_link(label, url)
    uri = URI.parse(url.to_s)
    return label unless %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?

    link_to(label, url, target: "_blank", rel: "noopener noreferrer", class: "underline")
  rescue URI::InvalidURIError
    label
  end

  def library_gallery_items(item)
    item.ordered_assets.map.with_index do |asset, index|
      definition = item.item_type_definition.media_role(asset.role)
      {
        key: "#{asset.role}-#{asset.position}",
        kind: definition.kind,
        asset:,
        alt: asset.alt_text,
        index: index + 1
      }
    end
  end

  def library_meta_description(item)
    strip_tags(item.summary.to_s).squish.truncate(155, separator: " ").presence
  end

  def library_filter_toggle_url(taxonomy_key, slug, selected:, item_types:, query: nil)
    next_selected = selected.transform_values(&:dup)
    current = next_selected[taxonomy_key] || []
    next_selected[taxonomy_key] = current.include?(slug) ? current - [ slug ] : current + [ slug ]
    query_params = next_selected.filter_map do |key, values|
      [ key, values.join(",") ] if values.any?
    end.to_h
    query_params[:type] = item_types.join(",") if item_types.any?
    query_params[:q] = query if query.present?
    library_path(query_params)
  end

  def library_type_toggle_url(item_type, selected:, taxonomies:, query: nil)
    next_selected = selected.include?(item_type) ? selected - [ item_type ] : selected + [ item_type ]
    query_params = taxonomies.filter_map do |key, values|
      [ key, values.join(",") ] if values.any?
    end.to_h
    query_params[:type] = next_selected.join(",") if next_selected.any?
    query_params[:q] = query if query.present?
    library_path(query_params)
  end

  def library_filter_active?(taxonomy_key, slug, selected:)
    selected.fetch(taxonomy_key, []).include?(slug)
  end

  def library_item_reference(item)
    {
      id: item.slug,
      type: item.item_type,
      title: item.title,
      summary: item.summary,
      url: library_item_path(item),
      retired: !item.published?
    }
  end

  private

  def strip_embedded_data_uri_references(value)
    value.to_s.each_line.reject do |line|
      line.match?(/\A\s*\[[^\]]+\]:\s*<data:image\/[^>]+>\s*\z/i)
    end.join
  end
end
