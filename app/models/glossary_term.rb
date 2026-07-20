# Persisted glossary entry synchronized from the active installation manifest.
class GlossaryTerm < ApplicationRecord
  include Translatable

  ID_FORMAT = /\A[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?\z/

  translates :term, :definition, :examples

  before_validation :assign_position, on: :create

  validates :slug, presence: true, uniqueness: true, format: { with: ID_FORMAT }
  validates :category, presence: true, inclusion: { in: ->(_record) { catalog.category_ids } }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  validate :base_locale_term_present
  validate :base_locale_definition_present
  validate :base_locale_term_unique

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :id) }

  def self.catalog
    @catalog ||= ResourceCatalog.glossary
  end

  def self.reset_catalog!
    @catalog = nil
  end

  def self.seed_from_yaml!(path: Rails.configuration.site.content.glossary,
                           overwrite: SeedPolicy.overwrite?(:glossary_terms))
    manifest = path == Rails.configuration.site.content.glossary ? catalog : ResourceCatalog::Manifest.load(
      path:, resource: "glossary",
      fields: { "term" => :string, "definition" => :string, "examples" => :array },
      optional_fields: %w[examples]
    )
    imported_ids = []

    transaction do
      manifest.entries.each do |entry|
        term = find_or_initialize_by(slug: entry.id)
        term.category = entry.category
        term.tags = entry.tags
        term.position = entry.position
        term.published = entry.published
        term.asset_path = entry.asset
        term.managed_by_manifest = true
        %w[term definition examples].each do |field|
          column = "#{field}_translations"
          term.public_send(
            "#{column}=",
            SeedPolicy.translations(term.public_send(column), translations_for(entry, field), overwrite:)
          )
        end
        term.save!
        imported_ids << term.id
      end

      where(managed_by_manifest: true).where.not(id: imported_ids).update_all(published: false, updated_at: Time.current)
    end
    count
  end

  def self.translations_for(entry, field)
    entry.translations.filter_map do |locale, values|
      [ locale, values[field] ] if values.key?(field)
    end.to_h
  end
  private_class_method :translations_for

  def to_param
    slug
  end

  def category_label(locale: I18n.locale)
    self.class.catalog.category(category)&.label(locale:, locales: Rails.configuration.site.locales) || category.humanize
  end

  def retire!
    update!(published: false)
  end

  private

  def assign_position
    self.position ||= self.class.maximum(:position).to_i + 1
  end

  def base_locale_term_present
    errors.add(:term_translations, :blank) unless base_locale_value(term_translations).present?
  end

  def base_locale_definition_present
    errors.add(:definition_translations, :blank) unless base_locale_value(definition_translations).present?
  end

  def base_locale_term_unique
    value = base_locale_value(term_translations)
    return if value.blank?

    scope = GlossaryTerm.where("LOWER(term_translations ->> ?) = ?", self.class.base_locale, value.downcase)
    scope = scope.where.not(id:) if persisted?
    errors.add(:term_translations, :taken) if scope.exists?
  end

  def base_locale_value(translations)
    (translations || {})[self.class.base_locale].to_s.strip
  end
end
