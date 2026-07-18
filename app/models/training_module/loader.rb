require "yaml"

# Reads Guides content declared by the installation's validated manifest.
class TrainingModule::Loader
  attr_reader :manifest

  def initialize(manifest: TrainingModule::Manifest.load, locales: Rails.configuration.site.locales)
    @manifest = manifest
    @locales = locales
  end

  def all(locale: I18n.locale)
    manifest.guides.filter(&:published).filter_map { |guide| build_module_info(guide, locale) }
  end

  def find(slug, locale: I18n.locale)
    guide = manifest.guides.find { |candidate| candidate.published && candidate.id == slug.to_s }
    build_module_info(guide, locale) if guide
  end

  # Returns content in the requested locale or the configured fallback chain.
  # The returned Section exposes both requested_locale and its actual locale so
  # callers can tell fallback content from unavailable content.
  def section(slug, volume, locale)
    guide = manifest.guides.find { |candidate| candidate.published && candidate.id == slug.to_s }
    section_definition = manifest.section(volume)
    return unless guide && section_definition

    requested_locale = locale.to_s
    translation = translation_for(guide, requested_locale)
    document = translation&.documents&.fetch(volume.to_s, nil)
    return unless document

    parse_file(
      document,
      guide:,
      translation:,
      section_definition:,
      requested_locale:
    )
  end

  def about(locale)
    requested_locale = locale.to_s
    actual_locale = locale_chain(requested_locale).find { |candidate| manifest.about_documents.key?(candidate) }
    path = manifest.about_documents[actual_locale]
    return unless path

    parse_about(path, requested_locale:, actual_locale:)
  end

  private

  attr_reader :locales

  def build_module_info(guide, locale)
    return unless guide
    translation = translation_for(guide, locale.to_s)
    return unless translation

    TrainingModule::ModuleInfo.new(
      slug: guide.id,
      title: translation.title,
      summary: translation.summary,
      cover: guide.cover,
      locale: translation.locale,
      requested_locale: locale.to_s,
      available_locales: locales.available.select { |candidate| guide.translations.key?(candidate) },
      available_sections: manifest.sections.map(&:id),
      section_labels: manifest.sections.to_h do |section|
        [ section.id, section.label(locale:, locales:) ]
      end
    )
  end

  def parse_file(path, guide:, translation:, section_definition:, requested_locale:)
    _frontmatter, body = split_frontmatter(path)
    TrainingModule::Section.new(
      title: translation.title,
      module_slug: guide.id,
      module_title: translation.title,
      summary: translation.summary,
      cover: guide.cover,
      locale: translation.locale,
      requested_locale:,
      volume: section_definition.id,
      section_title: section_definition.label(locale: requested_locale, locales:),
      available_modules: manifest.guides.filter(&:published).map(&:id),
      available_locales: locales.available.select { |candidate| guide.translations.key?(candidate) },
      available_sections: manifest.sections.map(&:id),
      section_labels: manifest.sections.to_h do |section|
        [ section.id, section.label(locale: requested_locale, locales:) ]
      end,
      body:
    )
  end

  def parse_about(path, requested_locale:, actual_locale:)
    frontmatter, body = split_frontmatter(path)
    TrainingModule::Section.new(
      title: frontmatter["title"],
      module_slug: nil,
      module_title: nil,
      summary: nil,
      cover: nil,
      locale: actual_locale,
      requested_locale:,
      volume: nil,
      section_title: nil,
      available_modules: manifest.guides.filter(&:published).map(&:id),
      available_locales: manifest.about_documents.keys,
      available_sections: [],
      section_labels: {},
      body:
    )
  end

  def translation_for(guide, locale)
    actual_locale = locale_chain(locale).find { |candidate| guide.translations.key?(candidate) }
    guide.translations[actual_locale]
  end

  def locale_chain(locale)
    locales.fallback_chain(locale)
  end

  def split_frontmatter(path)
    content = path.read
    if content.start_with?("---")
      parts = content.split(/^---\s*$\n?/, 3)
      [ YAML.safe_load(parts[1], permitted_classes: [], aliases: false) || {}, parts[2].to_s.strip ]
    else
      [ {}, content.strip ]
    end
  end
end
