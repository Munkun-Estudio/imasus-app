module BookmarksHelper
  def bookmark_dot_color(bookmark)
    resource_module_registry.for_bookmark_type(bookmark.bookmarkable_type)&.color ||
      "bg-brand-primary/20"
  end

  def bookmark_module_label(bookmark)
    resource_module = resource_module_registry.for_bookmark_type(bookmark.bookmarkable_type)
    resource_module ? resource_module_label(resource_module) : bookmark.bookmarkable_type.underscore.humanize
  end

  def bookmark_preview_image_src(bookmark)
    resource_module = resource_module_registry.for_bookmark_type(bookmark.bookmarkable_type)
    return unless resource_module&.bookmark_preview == :training_image

    slug, volume, locale, anchor = bookmark.resource_key.to_s.split("/", 4)
    return unless slug.present? && volume.present? && locale.present? && anchor&.match?(/\A(?:image|p)-\d+\z/)

    @bookmark_preview_image_src_cache ||= {}
    @bookmark_preview_image_src_cache[bookmark.resource_key] ||= begin
      section = TrainingModule::Loader.new.section(slug, volume, locale)
      if section
        fragment = Nokogiri::HTML5.fragment(TrainingModule::Renderer.call(section.body))
        node = fragment.at_css("##{anchor}")
        img = node&.name == "img" ? node : node&.at_css("img")
        src = img&.[]("src")
        src if src.present? && (src.start_with?("/") || src.match?(/\Ahttps?:\/\//))
      end
    end
  end
end
