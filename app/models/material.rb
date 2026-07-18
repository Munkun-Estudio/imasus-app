# A sustainable material featured in the installation catalogue.
#
# Materials are editorial content: participants browse them for inspiration
# before and during workshops. The model carries a mix of plain-string metadata
# (`trade_name`, `supplier_name`, `supplier_url`, `material_of_origin`) and
# five translatable narrative fields backed by JSONB columns via the
# {Translatable} concern (`description`, `interesting_properties`, `structure`,
# `sensorial_qualities`, `what_problem_it_solves`).
#
# Each material has a stable URL-safe `slug` derived from the English
# `trade_name` on create. The slug never auto-regenerates, so public URLs keep
# working if the trade name is later renamed.
#
# Faceted filtering on the catalogue page is powered by {Tag} associations
# through {MaterialTagging}, grouped by facet (`origin_type`,
# `textile_imitating`, `application`).
class Material < LibraryItem
  AVAILABILITY_STATUSES = %w[commercial in_development research_only].freeze

  # Translatable narrative fields rendered as prose sections on the detail
  # page. Ordered for reading: description → sensorial_qualities →
  # what_problem_it_solves → interesting_properties → structure.
  TRANSLATED_ATTRIBUTES = %i[
    description sensorial_qualities what_problem_it_solves
    interesting_properties structure
  ].freeze

  SEED_PATH = Rails.configuration.site.content.library

  enum :availability_status, AVAILABILITY_STATUSES.each_with_index.to_h

  default_scope { where(item_type: "material", published: true) }

  has_many :taggings, class_name: "MaterialTagging", foreign_key: :library_item_id,
                      dependent: :destroy, inverse_of: :material
  has_many :tags, through: :taggings, source: :tag

  has_many :assets, -> { order(:kind, :position) },
           class_name: "MaterialAsset", foreign_key: :library_item_id,
           dependent: :destroy, inverse_of: :material

  translates :description, :interesting_properties, :structure,
             :sensorial_qualities, :what_problem_it_solves

  before_validation :generate_slug, on: :create
  before_validation :sync_library_from_legacy

  validates :trade_name,          presence: true
  validates :slug,                presence: true, uniqueness: { case_sensitive: false }
  validates :availability_status, presence: true

  validate :base_locale_description_present

  # @return [String] the slug, so helpers like `material_path(material)` use it
  def to_param
    slug
  end

  # Returns the material's tags for a given facet.
  #
  # @param facet [Symbol, String] one of `:origin_type`, `:textile_imitating`, `:application`
  # @return [Array<Tag>]
  def tags_for(facet)
    tags.where(facet: facet.to_s).to_a
  end

  # @return [MaterialAsset, nil] the first macro (hero) asset, if attached.
  def macro_asset
    return macro_assets.first if assets.loaded?

    assets.where(kind: :macro).order(:position).first
  end

  # @return [ActiveRecord::Relation<MaterialAsset>, Array<MaterialAsset>] macro images ordered
  #   by their stable source position.
  def macro_assets
    return assets.select(&:macro?).sort_by(&:position) if assets.loaded?

    assets.where(kind: :macro).order(:position)
  end

  # @return [MaterialAsset, nil] the image used in compact cover contexts.
  #   Prefer the macro photo, falling back to the first microscopy when a
  #   material has microscopy media but no macro.
  def cover_asset
    macro_asset || microscopies.first
  end

  # @return [ActiveRecord::Relation<MaterialAsset>, Array<MaterialAsset>] microscopy assets ordered
  #   from highest zoom (position 0, the `m1` slot) to lowest.
  def microscopies
    return assets.select(&:microscopy?).sort_by(&:position) if assets.loaded?

    assets.where(kind: :microscopy).order(:position)
  end

  # @return [MaterialAsset, nil] the single video asset, if attached.
  def video_asset
    return assets.find(&:video?) if assets.loaded?

    assets.find_by(kind: :video)
  end

  # Compatibility entrypoint. Library content now comes from the generic
  # manifest configured by the active installation profile.
  def self.seed_from_yaml!(path: SEED_PATH, overwrite: SeedPolicy.overwrite?(:materials))
    manifest = LibraryCatalog::Manifest.load(path:)
    LibraryItem.seed_from_manifest!(manifest:, overwrite:)
    of_type("material").count
  end

  def sync_legacy_from_library!
    fallback = self.class.base_locale.to_s
    self.trade_name = title_translations.to_h[fallback]
    self.description_translations = summary_translations
    self.supplier_name = custom_fields.to_h["supplier_name"]
    self.supplier_url = custom_fields.to_h["supplier_url"]
    self.material_of_origin = custom_fields.to_h["material_of_origin"]
    self.availability_status = custom_fields.to_h["availability_status"]
    self.interesting_properties_translations = custom_fields.to_h.fetch("interesting_properties", {})
    self.structure_translations = custom_fields.to_h.fetch("structure", {})
    self.sensorial_qualities_translations = custom_fields.to_h.fetch("sensorial_qualities", {})
    self.what_problem_it_solves_translations = custom_fields.to_h.fetch("what_problem_it_solves", {})
    self
  end

  private

  def generate_slug
    return if slug.present?

    self.slug = trade_name.to_s.parameterize.presence
  end

  def sync_library_from_legacy
    self.item_type = "material"
    fallback = self.class.base_locale.to_s
    if new_record? || will_save_change_to_trade_name?
      self.title_translations = title_translations.to_h.merge(fallback => trade_name)
    end
    if new_record? || will_save_change_to_description_translations?
      self.summary_translations = description_translations
    end

    fields = custom_fields.to_h.dup
    sync_custom_field(fields, "supplier_name", supplier_name)
    sync_custom_field(fields, "supplier_url", supplier_url)
    sync_custom_field(fields, "material_of_origin", material_of_origin)
    sync_custom_field(fields, "availability_status", availability_status)
    sync_custom_field(fields, "interesting_properties", interesting_properties_translations)
    sync_custom_field(fields, "structure", structure_translations)
    sync_custom_field(fields, "sensorial_qualities", sensorial_qualities_translations)
    sync_custom_field(fields, "what_problem_it_solves", what_problem_it_solves_translations)
    self.custom_fields = fields

    return unless new_record? || will_save_change_to_supplier_url? || will_save_change_to_supplier_name?

    self.links = if supplier_url.present?
      [ { "label" => supplier_name.presence || trade_name, "url" => supplier_url } ]
    else
      []
    end
  end

  def sync_custom_field(fields, key, value)
    if value.present?
      fields[key] = value
    else
      fields.delete(key)
    end
  end

  def base_locale_description_present
    return if description_in(self.class.base_locale).to_s.strip.present?

    errors.add(:description_translations, :blank)
  end
end

LibraryItem.register_adapter("material", Material)
