# A multi-facet, multi-select tag used to filter the IMASUS materials
# catalogue.
#
# Tags are grouped by {FACETS} — `origin_type`, `textile_imitating`, and
# `application` — each representing one chip group on the materials index.
# The `name` attribute is translatable via the {Translatable} concern so chips
# render in the user's current locale with English fallback.
#
# Slug uniqueness is scoped to `facet` so, for example, a `plants` slug in
# `origin_type` and a `plants` slug in `application` (were it ever needed)
# would not collide.
class Tag < ApplicationRecord
  include Translatable

  FACETS = %w[origin_type textile_imitating application].freeze

  BASE_LOCALE = "en"

  SEED_PATH = Rails.root.join("db", "seeds", "material_tags.yml")

  enum :facet, FACETS.each_with_index.to_h

  has_many :taggings, class_name: "MaterialTagging", dependent: :destroy
  has_many :materials, through: :taggings

  translates :name

  validates :facet, presence: true
  validates :slug,  presence: true, uniqueness: { scope: :facet, case_sensitive: false }

  validate :base_locale_name_present

  # @param path [Pathname, String] seed file path
  # @return [Integer] the number of tags after loading
  def self.seed_from_yaml!(path: SEED_PATH)
    entries = YAML.load_file(path)

    entries.each do |entry|
      facet = entry.fetch("facet")
      slug  = entry.fetch("slug")

      tag = find_or_initialize_by(facet: facet, slug: slug)
      tag.name_translations = entry.fetch("name")
      tag.save!
    end

    count
  end

  private

  def base_locale_name_present
    return if name_in(BASE_LOCALE).to_s.strip.present?

    errors.add(:name_translations, :blank)
  end
end
