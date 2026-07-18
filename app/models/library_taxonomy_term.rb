# A reusable term grouped under a manifest-defined Library taxonomy.
class LibraryTaxonomyTerm < ApplicationRecord
  include Translatable

  translates :name

  has_many :taggings, class_name: "LibraryItemTagging", dependent: :destroy,
                      inverse_of: :library_taxonomy_term
  has_many :library_items, through: :taggings

  validates :taxonomy_key, :slug, presence: true
  validates :slug, uniqueness: { scope: :taxonomy_key, case_sensitive: false }
  validate :fallback_name_present

  scope :published, -> { where(published: true) }
  scope :for_taxonomy, ->(key) { where(taxonomy_key: key.to_s) }

  class << self
    def register_adapter(taxonomy_key, model)
      adapters[taxonomy_key.to_s] = model
    end

    def adapter_for(taxonomy_key)
      adapters.fetch(taxonomy_key.to_s, self)
    end

    private

    def adapters
      @adapters ||= {}
    end
  end

  def self.seed_from_manifest!(manifest: LibraryCatalog.current,
                               overwrite: SeedPolicy.overwrite?(:library))
    manifest.taxonomies.each do |taxonomy|
      taxonomy.terms.each do |entry|
        model = adapter_for(taxonomy.id)
        term = model.find_or_initialize_by(taxonomy_key: taxonomy.id, slug: entry.id)
        term.position = entry.position
        term.published = true
        term.managed_by_manifest = true
        term.name_translations = SeedPolicy.translations(
          term.name_translations,
          entry.labels,
          overwrite:
        )
        term.sync_legacy_from_library! if term.respond_to?(:sync_legacy_from_library!)
        term.save!
      end
    end

    identities = manifest.taxonomies.flat_map do |taxonomy|
      taxonomy.terms.map { |term| [ taxonomy.id, term.id ] }
    end
    where(managed_by_manifest: true).find_each do |term|
      term.update!(published: false) unless identities.include?([ term.taxonomy_key, term.slug ])
    end
    count
  end

  private

  def fallback_name_present
    errors.add(:name_translations, :blank) if name_in(self.class.base_locale).blank?
  end
end
