# A shared vocabulary entry used across IMASUS workshop content.
#
# Each term carries translations for `term`, `definition`, and `examples` via
# the {Translatable} concern, plus a `category` (one of {CATEGORIES}) and a
# URL-safe `slug` derived from the English term on create. The slug is stable
# for the life of the record so published URLs keep working even if curators
# later rename the term.
#
# Base-locale presence validations ensure every term has at least an English
# source; other locales are optional stubs that can be filled in over time.
class GlossaryTerm < ApplicationRecord
  include Translatable

  # Fixed list of category values. Kept intentionally small — a fifth value is a
  # one-line change to this constant, no migration needed.
  CATEGORIES = %w[methodology application industry science].freeze

  # The source-of-truth locale for slug generation, presence validation, and
  # case-insensitive uniqueness.
  BASE_LOCALE = "en"

  # Default seed file path. Override via the `path:` argument to {.seed_from_yaml!}.
  SEED_PATH = Rails.root.join("db", "seeds", "glossary_terms.yml")

  translates :term, :definition, :examples

  before_validation :generate_slug, on: :create

  validates :slug,     presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  validate :base_locale_term_present
  validate :base_locale_definition_present
  validate :base_locale_term_unique

  # @return [String] the slug, so helpers like `glossary_term_path(term)` use it
  def to_param
    slug
  end

  # Idempotent loader that upserts every entry in the seed YAML. Each entry is
  # matched by a slug derived from its English `term`, so re-running the loader
  # updates translations, category, and examples without duplicating rows.
  #
  # @param path [Pathname, String] seed file path (tests override this)
  # @return [Integer] the number of glossary terms after loading
  # @raise [ActiveRecord::RecordInvalid] if any entry fails validation
  def self.seed_from_yaml!(path: SEED_PATH)
    entries = YAML.load_file(path)

    entries.each do |entry|
      slug = entry.dig("term", "en").to_s.parameterize

      term = find_or_initialize_by(slug: slug)
      term.term_translations       = entry.fetch("term")
      term.definition_translations = entry.fetch("definition")
      term.examples_translations   = entry.fetch("examples", {})
      term.category                = entry.fetch("category")
      term.save!
    end

    count
  end

  private

  def generate_slug
    return if slug.present?

    self.slug = base_locale_value(term_translations).parameterize.presence
  end

  def base_locale_term_present
    return if base_locale_value(term_translations).present?

    errors.add(:term_translations, :blank)
  end

  def base_locale_definition_present
    return if base_locale_value(definition_translations).present?

    errors.add(:definition_translations, :blank)
  end

  def base_locale_term_unique
    value = base_locale_value(term_translations)
    return if value.blank?

    scope = GlossaryTerm.where("LOWER(term_translations->>'en') = ?", value.downcase)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:term_translations, :taken) if scope.exists?
  end

  def base_locale_value(translations)
    (translations || {})[BASE_LOCALE].to_s.strip
  end
end
