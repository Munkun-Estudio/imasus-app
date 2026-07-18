# Lightweight metadata for a Guide declared in the content manifest.
class TrainingModule::ModuleInfo
  attr_reader :slug, :title, :summary, :cover, :locale, :requested_locale,
              :available_locales, :available_sections, :section_labels

  def initialize(slug:, title:, summary:, cover:, locale:, requested_locale:,
                 available_locales:, available_sections:, section_labels:)
    @slug = slug
    @title = title
    @summary = summary
    @cover = cover
    @locale = locale
    @requested_locale = requested_locale
    @available_locales = available_locales
    @available_sections = available_sections
    @section_labels = section_labels
  end

  def fallback?
    locale != requested_locale
  end
end
