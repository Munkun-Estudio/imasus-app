# Generic, manifest-defined content item in an installation's Library.
class LibraryItem < ApplicationRecord
  include Translatable
  include ActionText::Attachable

  attr_accessor :validation_manifest

  translates :title, :summary

  has_many :taggings, class_name: "LibraryItemTagging", dependent: :destroy,
                      inverse_of: :library_item
  has_many :taxonomy_terms, through: :taggings, source: :library_taxonomy_term
  has_many :assets, -> { active.order(:position) },
           class_name: "LibraryItemAsset", dependent: :destroy,
           inverse_of: :library_item

  validates :slug, presence: true, uniqueness: { case_sensitive: false }
  validates :item_type, presence: true
  validate :fallback_content_present
  validate :manifest_data_is_valid

  scope :published, -> { where(published: true) }
  scope :of_type, ->(item_type) { where(item_type: item_type.to_s) }

  class << self
    def register_adapter(item_type, model)
      adapters[item_type.to_s] = model
    end

    def adapter_for(item_type)
      adapters.fetch(item_type.to_s, self)
    end

    def seed_from_manifest!(manifest: LibraryCatalog.current,
                            overwrite: SeedPolicy.overwrite?(:library))
      LibraryTaxonomyTerm.seed_from_manifest!(manifest:, overwrite:)

      manifest.items.each do |entry|
        model = adapter_for(entry.item_type)
        item = model.unscoped.find_or_initialize_by(slug: entry.id)
        assign_manifest_entry(item, entry, overwrite:, manifest:)
        item.sync_legacy_from_library! if item.respond_to?(:sync_legacy_from_library!)
        item.save!
        sync_taxonomies!(item, entry)
      end

      manifest_ids = manifest.items.map(&:id)
      where(managed_by_manifest: true).where.not(slug: manifest_ids).update_all(published: false)
      count
    end

    private

    def adapters
      @adapters ||= {}
    end

    def assign_manifest_entry(item, entry, overwrite:, manifest:)
      item.validation_manifest = manifest
      item.item_type = entry.item_type
      item.position = entry.position
      item.published = entry.published
      item.managed_by_manifest = true
      item.title_translations = SeedPolicy.translations(
        item.title_translations,
        translations_for(entry, "title"),
        overwrite:
      )
      item.summary_translations = SeedPolicy.translations(
        item.summary_translations,
        translations_for(entry, "summary"),
        overwrite:
      )
      item.custom_fields = merge_custom_fields(item.custom_fields, entry.fields, overwrite:)
      item.links = SeedPolicy.value(item.links, json_links(entry.links), overwrite:)
    end

    def translations_for(entry, field)
      entry.translations.to_h { |locale, values| [ locale, values.fetch(field) ] }
    end

    def merge_custom_fields(current, seeded, overwrite:)
      current = (current || {}).stringify_keys
      return seeded.deep_dup if overwrite

      seeded.each do |key, value|
        current[key] = if value.is_a?(Hash)
          SeedPolicy.translations(current[key], value, overwrite: false)
        else
          SeedPolicy.value(current[key], value, overwrite: false)
        end
      end
      current
    end

    def json_links(links)
      links.map { |link| { "label" => link.label, "url" => link.url } }
    end

    def sync_taxonomies!(item, entry)
      term_ids = entry.taxonomies.flat_map do |taxonomy_key, slugs|
        LibraryTaxonomyTerm.where(taxonomy_key:, slug: slugs).pluck(:id)
      end
      item.taggings.where.not(library_taxonomy_term_id: term_ids).destroy_all
      existing_ids = item.taggings.pluck(:library_taxonomy_term_id)
      (term_ids - existing_ids).each do |term_id|
        item.taggings.create!(library_taxonomy_term_id: term_id)
      end
    end
  end

  def to_param
    slug
  end

  def to_attachable_partial_path
    "library_items/reference"
  end

  def attachable_plain_text_representation(caption = nil)
    caption.presence || title
  end

  def field_value(field_id, locale: I18n.locale)
    field = item_type_definition&.field(field_id)
    return unless field

    value = custom_fields.to_h[field.id]
    return value unless field.localized && value.is_a?(Hash)

    Rails.configuration.site.locales.fallback_chain(locale)
         .filter_map { |candidate| value[candidate] }
         .first
  end

  def item_type_definition
    LibraryCatalog.current.item_type(item_type)
  end

  def taxonomy_terms_for(taxonomy_key)
    taxonomy_terms.where(taxonomy_key: taxonomy_key.to_s).order(:position)
  end

  def cover_asset
    role = item_type_definition&.cover_role&.id
    role ? assets.find { |asset| asset.role == role && asset.file.attached? } : nil
  end

  def ordered_assets(placement: "gallery")
    roles = item_type_definition&.media.to_a.select { |role| role.placement == placement }
    positions = roles.map.with_index.to_h { |role, index| [ role.id, index ] }
    assets.select { |asset| positions.key?(asset.role) && asset.file.attached? }
          .sort_by { |asset| [ positions.fetch(asset.role), asset.position ] }
  end

  private

  def fallback_content_present
    fallback = self.class.base_locale
    errors.add(:title_translations, :blank) if title_in(fallback).blank?
    errors.add(:summary_translations, :blank) if summary_in(fallback).blank?
  end

  def manifest_data_is_valid
    (validation_manifest || LibraryCatalog.current).validate_item_data!(
      item_type_id: item_type,
      fields: custom_fields,
      links: links
    )
  rescue LibraryCatalog::Manifest::Error => error
    errors.add(:custom_fields, error.message)
  end
end
