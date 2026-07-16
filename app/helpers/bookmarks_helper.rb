module BookmarksHelper
  BOOKMARK_DOT_COLORS = {
    "TrainingModule" => "bg-brand-secondary",
    "Material"       => "bg-brand-info",
    "Challenge"      => "bg-brand-success",
    "GlossaryTerm"   => "bg-brand-soft"
  }.freeze

  def bookmark_dot_color(bookmark)
    BOOKMARK_DOT_COLORS.fetch(bookmark.bookmarkable_type, "bg-brand-primary/20")
  end

  def bookmark_preview_image_src(bookmark)
    return unless bookmark.bookmarkable_type == "TrainingModule"

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
