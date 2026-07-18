# Persisted prompt content synchronized from the active installation manifest.
# The historical class and table names remain for URL, project, and bookmark
# compatibility with IMASUS.
class Challenge < ApplicationRecord
  include Translatable

  ID_FORMAT = /\A[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?\z/i

  translates :question, :description

  before_validation :normalize_code
  before_validation :assign_position, on: :create

  validates :code, presence: true, format: { with: ID_FORMAT }
  validates :category, presence: true, inclusion: { in: ->(_record) { catalog.category_ids } }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  validate :unique_code_case_insensitive
  validate :base_locale_question_present
  validate :base_locale_description_present

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :by_code, -> { ordered }

  def self.catalog
    @catalog ||= ResourceCatalog.prompts
  end

  def self.reset_catalog!
    @catalog = nil
  end

  def self.seed_from_yaml!(path: Rails.configuration.site.content.prompts,
                           overwrite: SeedPolicy.overwrite?(:challenges))
    manifest = path == Rails.configuration.site.content.prompts ? catalog : ResourceCatalog::Manifest.load(
      path:, resource: "prompts", fields: { "question" => :string, "description" => :string }
    )
    imported_ids = []

    transaction do
      manifest.entries.each do |entry|
        challenge = where("LOWER(code) = ?", entry.id.downcase).first_or_initialize
        challenge.code = entry.id
        challenge.category = entry.category
        challenge.tags = entry.tags
        challenge.position = entry.position
        challenge.published = entry.published
        challenge.asset_path = entry.asset
        challenge.managed_by_manifest = true
        challenge.question_translations = SeedPolicy.translations(
          challenge.question_translations,
          translations_for(entry, "question"),
          overwrite:
        )
        challenge.description_translations = SeedPolicy.translations(
          challenge.description_translations,
          translations_for(entry, "description"),
          overwrite:
        )
        challenge.save!
        imported_ids << challenge.id
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
    code&.downcase
  end

  def category_label(locale: I18n.locale)
    self.class.catalog.category(category)&.label(locale:, locales: Rails.configuration.site.locales) || category.humanize
  end

  private

  def normalize_code
    self.code = code.upcase if code.to_s.match?(/\Ac\d+\z/i)
  end

  def assign_position
    self.position ||= self.class.maximum(:position).to_i + 1
  end

  def unique_code_case_insensitive
    return if code.blank?
    scope = Challenge.unscoped.where("UPPER(code) = ?", code.upcase)
    scope = scope.where.not(id:) if persisted?
    errors.add(:code, :taken) if scope.exists?
  end

  def base_locale_question_present
    errors.add(:question_translations, :blank) unless base_locale_value(question_translations).present?
  end

  def base_locale_description_present
    errors.add(:description_translations, :blank) unless base_locale_value(description_translations).present?
  end

  def base_locale_value(translations)
    (translations || {})[self.class.base_locale].to_s.strip
  end
end
