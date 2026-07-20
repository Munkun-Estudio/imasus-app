# One localized document from a manifest-driven Guide collection.
class TrainingModule::Section
  attr_reader :title, :module_slug, :module_title, :summary, :cover, :locale,
              :requested_locale, :volume, :section_title, :available_modules,
              :available_locales, :available_sections, :section_labels, :body

  def initialize(title:, module_slug:, module_title:, summary:, cover:, locale:,
                 requested_locale:, volume:, section_title:, available_modules:,
                 available_locales:, available_sections:, section_labels:, body:)
    @title = title
    @module_slug = module_slug
    @module_title = module_title
    @summary = summary
    @cover = cover
    @locale = locale
    @requested_locale = requested_locale
    @volume = volume
    @section_title = section_title
    @available_modules = available_modules
    @available_locales = available_locales
    @available_sections = available_sections
    @section_labels = section_labels
    @body = body
  end

  def fallback?
    locale != requested_locale
  end
end
