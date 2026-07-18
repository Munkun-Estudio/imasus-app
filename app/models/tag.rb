# A multi-facet, multi-select tag used to filter library materials.
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
class Tag < LibraryTaxonomyTerm
  FACETS = %w[origin_type textile_imitating application].freeze

  SEED_PATH = Rails.configuration.site.content.library

  enum :facet, FACETS.each_with_index.to_h

  has_many :taggings, class_name: "MaterialTagging", foreign_key: :library_taxonomy_term_id,
                      dependent: :destroy, inverse_of: :tag
  has_many :materials, through: :taggings, source: :material

  validates :facet, presence: true
  validates :slug,  presence: true, uniqueness: { scope: :facet, case_sensitive: false }

  validate :base_locale_name_present
  before_validation :sync_library_taxonomy

  # Existing tags keep edited names by default; pass `overwrite: true` or set
  # `SEED_OVERWRITE_CONTENT=1` / `SEED_TAGS=overwrite` to intentionally refresh
  # content from YAML.
  #
  # @param path [Pathname, String] seed file path
  # @param overwrite [Boolean] whether existing content should be replaced
  # @return [Integer] the number of tags after loading
  def self.seed_from_yaml!(path: SEED_PATH, overwrite: SeedPolicy.overwrite?(:tags))
    manifest = LibraryCatalog::Manifest.load(path:)
    LibraryTaxonomyTerm.seed_from_manifest!(manifest:, overwrite:)
    where(taxonomy_key: FACETS).count
  end

  def sync_legacy_from_library!
    self.facet = taxonomy_key if FACETS.include?(taxonomy_key)
    self
  end

  private

  def base_locale_name_present
    return if name_in(self.class.base_locale).to_s.strip.present?

    errors.add(:name_translations, :blank)
  end

  def sync_library_taxonomy
    self.taxonomy_key = facet if taxonomy_key.blank? && facet.present?
  end
end

Tag::FACETS.each { |facet| LibraryTaxonomyTerm.register_adapter(facet, Tag) }
