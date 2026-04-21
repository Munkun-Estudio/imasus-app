# A sustainable material featured in the IMASUS catalogue.
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
class Material < ApplicationRecord
  include Translatable

  AVAILABILITY_STATUSES = %w[commercial in_development research_only].freeze

  BASE_LOCALE = "en"

  SEED_PATH = Rails.root.join("db", "seeds", "materials.yml")

  enum :availability_status, AVAILABILITY_STATUSES.each_with_index.to_h

  has_many :taggings, class_name: "MaterialTagging", dependent: :destroy
  has_many :tags, through: :taggings

  has_many :assets, -> { order(:kind, :position) },
           class_name: "MaterialAsset", dependent: :destroy

  translates :description, :interesting_properties, :structure,
             :sensorial_qualities, :what_problem_it_solves

  before_validation :generate_slug, on: :create

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

  # @return [MaterialAsset, nil] the single macro (hero) asset, if attached.
  def macro_asset
    assets.find_by(kind: :macro)
  end

  # @return [ActiveRecord::Relation<MaterialAsset>] microscopy assets ordered
  #   from highest zoom (position 0, the `m1` slot) to lowest.
  def microscopies
    assets.where(kind: :microscopy).order(:position)
  end

  # @return [MaterialAsset, nil] the single video asset, if attached.
  def video_asset
    assets.find_by(kind: :video)
  end

  # Idempotent loader that upserts every entry in the seed YAML. Matches each
  # record by the slug derived from the English `trade_name`, so re-running the
  # loader updates translations, tags, and metadata without duplicating rows.
  #
  # @param path [Pathname, String] seed file path
  # @return [Integer] the number of materials after loading
  # @raise [ActiveRecord::RecordInvalid] if any entry fails validation
  # @raise [ArgumentError] if a material entry references an unknown tag slug
  def self.seed_from_yaml!(path: SEED_PATH)
    entries = YAML.load_file(path)

    entries.each_with_index do |entry, index|
      trade_name = entry.fetch("trade_name")
      slug       = entry.fetch("slug") { trade_name.parameterize }

      material = find_or_initialize_by(slug: slug)
      material.trade_name          = trade_name
      material.supplier_name       = entry["supplier_name"]
      material.supplier_url        = entry["supplier_url"]
      material.material_of_origin  = entry["material_of_origin"]
      material.availability_status = entry.fetch("availability_status")
      material.position            = entry.fetch("position", index)

      material.description_translations            = entry.fetch("description", {})
      material.interesting_properties_translations = entry.fetch("interesting_properties", {})
      material.structure_translations              = entry.fetch("structure", {})
      material.sensorial_qualities_translations    = entry.fetch("sensorial_qualities", {})
      material.what_problem_it_solves_translations = entry.fetch("what_problem_it_solves", {})

      material.save!

      apply_tags!(material, entry["tags"] || {})
    end

    count
  end

  # Replaces the material's taggings with the ones described by the entry.
  #
  # @api private
  # @param material [Material]
  # @param tags_by_facet [Hash{String => Array<String>}] facet => tag slugs
  # @raise [ArgumentError] if any tag slug is unknown
  def self.apply_tags!(material, tags_by_facet)
    tag_ids = tags_by_facet.flat_map do |facet, slugs|
      Array(slugs).map { |slug| resolve_tag_id!(facet, slug) }
    end

    material.taggings.where.not(tag_id: tag_ids).destroy_all

    (tag_ids - material.tags.pluck(:id)).each do |tag_id|
      material.taggings.create!(tag_id: tag_id)
    end
  end

  def self.resolve_tag_id!(facet, slug)
    Tag.where(facet: facet, slug: slug).pick(:id) ||
      raise(ArgumentError, "Unknown tag: facet=#{facet}, slug=#{slug}")
  end

  private_class_method :apply_tags!, :resolve_tag_id!

  private

  def generate_slug
    return if slug.present?

    self.slug = trade_name.to_s.parameterize.presence
  end

  def base_locale_description_present
    return if description_in(BASE_LOCALE).to_s.strip.present?

    errors.add(:description_translations, :blank)
  end
end
