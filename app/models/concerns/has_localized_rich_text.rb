module HasLocalizedRichText
  extend ActiveSupport::Concern

  included do
    has_many :localized_rich_texts,
             as: :record,
             dependent: :destroy,
             autosave: true
  end

  def localized_rich_text_in(name, locale)
    localized_rich_text_entry(name, locale)&.content
  end

  def localized_rich_text_for(name, locale = I18n.locale)
    site_locales.fallback_chain(locale).each do |candidate|
      entry = localized_rich_text_entry(name, candidate)
      return entry.content if entry&.content_present?
    end

    nil
  end

  def localized_rich_text_present?(name, locale)
    localized_rich_text_entry(name, locale)&.content_present? || false
  end

  def assign_localized_rich_text(name, locale, value)
    locale = locale.to_s
    unless site_locales.available.include?(locale)
      raise ArgumentError, "Unsupported locale #{locale.inspect}"
    end

    entry = localized_rich_text_entry(name, locale) ||
            localized_rich_texts.build(name: name.to_s, locale:)
    entry.content = value
  end

  private

  def localized_rich_text_entry(name, locale)
    name = name.to_s
    locale = locale.to_s

    localized_rich_texts.detect do |entry|
      entry.name == name && entry.locale == locale
    end
  end

  def site_locales
    Rails.configuration.site.locales
  end
end
