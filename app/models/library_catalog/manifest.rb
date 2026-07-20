require "pathname"
require "uri"
require "yaml"

# Strict, non-executable contract for an installation's reusable Library.
class LibraryCatalog::Manifest
  class Error < StandardError; end

  Field = Data.define(
    :id, :kind, :localized, :required, :cardinality, :labels, :options,
    :display, :card
  ) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end

    def multiple?
      cardinality == "many"
    end
  end

  Media = Data.define(
    :id, :position, :kind, :multiple, :placement, :cover, :allowed_types,
    :max_bytes
  )

  ItemType = Data.define(:id, :position, :labels, :fields, :media) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end

    def field(id)
      fields.find { |candidate| candidate.id == id.to_s }
    end

    def media_role(id)
      media.find { |candidate| candidate.id == id.to_s }
    end

    def cover_role
      media.find(&:cover)
    end
  end

  Term = Data.define(:id, :position, :labels) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end
  end

  Taxonomy = Data.define(:id, :position, :cardinality, :filter, :labels, :terms) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end

    def term(id)
      terms.find { |candidate| candidate.id == id.to_s }
    end
  end

  Link = Data.define(:label, :url)
  Asset = Data.define(:role, :path, :alt)
  Item = Data.define(
    :id, :position, :item_type, :published, :translations, :fields,
    :taxonomies, :links, :assets
  )

  ID_FORMAT = /\A[a-z0-9]+(?:[a-z0-9_-]*[a-z0-9])?\z/
  FIELD_KINDS = %w[string text url number boolean select].freeze
  FIELD_DISPLAYS = %w[body metadata hidden].freeze
  CARDINALITIES = %w[one many].freeze
  MEDIA_KINDS = %w[image video file].freeze
  MEDIA_PLACEMENTS = %w[gallery download].freeze
  TOP_LEVEL_KEYS = %w[version resource item_types taxonomies items].freeze
  ITEM_TYPE_KEYS = %w[id labels fields media].freeze
  FIELD_KEYS = %w[id kind localized required cardinality labels options display card].freeze
  MEDIA_KEYS = %w[id kind multiple placement cover allowed_types max_bytes].freeze
  TAXONOMY_KEYS = %w[id cardinality filter labels terms].freeze
  TERM_KEYS = %w[id labels].freeze
  ITEM_KEYS = %w[id item_type published translations fields taxonomies links assets].freeze
  TRANSLATION_KEYS = %w[title summary].freeze
  LINK_KEYS = %w[label url].freeze
  ASSET_KEYS = %w[role path alt].freeze

  attr_reader :path, :item_types, :taxonomies, :items

  def self.load(path:)
    new(path:).load
  end

  def initialize(path:)
    @path = Pathname(path)
    @locales = Rails.configuration.site.locales
  end

  def load
    payload = YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}
    payload = hash!(payload, "manifest")
    keys!(payload, TOP_LEVEL_KEYS, "manifest")
    raise Error, "#{path} version must be 1" unless payload["version"] == 1
    raise Error, "#{path} resource must be \"library\"" unless payload["resource"] == "library"

    @item_types = build_item_types(payload["item_types"]).freeze
    @taxonomies = build_taxonomies(payload["taxonomies"]).freeze
    @items = build_items(payload["items"]).freeze
    self
  rescue Psych::Exception => error
    raise Error, "Could not parse #{path}: #{error.message}"
  end

  def item_type(id)
    item_types.find { |candidate| candidate.id == id.to_s }
  end

  def item_type_ids
    item_types.map(&:id)
  end

  def taxonomy(id)
    taxonomies.find { |candidate| candidate.id == id.to_s }
  end

  def taxonomy_ids
    taxonomies.map(&:id)
  end

  def validate_item_data!(item_type_id:, fields:, links:)
    type = item_type(item_type_id)
    raise Error, "Unknown item type #{item_type_id.inspect}" unless type

    validate_fields!(hash!(fields || {}, "custom_fields"), type:, location: "custom_fields")
    links!(links || [], "links")
    true
  end

  private

  attr_reader :locales

  def build_item_types(source)
    items = array!(source, "item_types").map.with_index do |entry, index|
      location = "item_types[#{index}]"
      entry = hash!(entry, location)
      keys!(entry, ITEM_TYPE_KEYS, location)
      fields = build_fields(entry["fields"], location: "#{location}.fields")
      media = build_media(entry["media"], location: "#{location}.media")
      ItemType.new(
        id: id!(entry["id"], "#{location}.id"),
        position: index,
        labels: localized_labels!(entry["labels"], "#{location}.labels"),
        fields:,
        media:
      ).freeze
    end
    raise Error, "#{path} must define at least one item type" if items.empty?
    duplicate!(items.map(&:id), "item type")
    items
  end

  def build_fields(source, location:)
    fields = array!(source, location).map.with_index do |entry, index|
      field_location = "#{location}[#{index}]"
      entry = hash!(entry, field_location)
      keys!(entry, FIELD_KEYS, field_location)
      kind = enum!(entry["kind"], FIELD_KINDS, "#{field_location}.kind")
      options = options!(entry["options"], kind:, location: "#{field_location}.options")
      Field.new(
        id: id!(entry["id"], "#{field_location}.id"),
        kind:,
        localized: boolean!(entry["localized"], "#{field_location}.localized"),
        required: boolean!(entry["required"], "#{field_location}.required"),
        cardinality: enum!(entry["cardinality"], CARDINALITIES, "#{field_location}.cardinality"),
        labels: localized_labels!(entry["labels"], "#{field_location}.labels"),
        options:,
        display: enum!(entry["display"], FIELD_DISPLAYS, "#{field_location}.display"),
        card: boolean!(entry["card"], "#{field_location}.card")
      ).freeze
    end
    duplicate!(fields.map(&:id), "field in #{location}")
    fields.freeze
  end

  def build_media(source, location:)
    roles = array!(source, location).map.with_index do |entry, index|
      role_location = "#{location}[#{index}]"
      entry = hash!(entry, role_location)
      keys!(entry, MEDIA_KEYS, role_location)
      kind = enum!(entry["kind"], MEDIA_KINDS, "#{role_location}.kind")
      allowed_types = media_types!(entry["allowed_types"], kind:, location: "#{role_location}.allowed_types")
      placement = enum!(entry["placement"], MEDIA_PLACEMENTS, "#{role_location}.placement")
      if (placement == "gallery" && kind == "file") || (placement == "download" && kind != "file")
        raise Error, "#{role_location}.placement is incompatible with media kind #{kind.inspect}"
      end
      max_bytes = entry["max_bytes"]
      unless max_bytes.is_a?(Integer) && max_bytes.positive? && max_bytes <= 500.megabytes
        raise Error, "#{role_location}.max_bytes must be between 1 and 524288000"
      end

      Media.new(
        id: id!(entry["id"], "#{role_location}.id"),
        position: index,
        kind:,
        multiple: boolean!(entry["multiple"], "#{role_location}.multiple"),
        placement:,
        cover: boolean!(entry["cover"], "#{role_location}.cover"),
        allowed_types:,
        max_bytes:
      ).freeze
    end
    duplicate!(roles.map(&:id), "media role in #{location}")
    raise Error, "#{location} accepts at most one cover role" if roles.count(&:cover) > 1
    roles.freeze
  end

  def media_types!(source, kind:, location:)
    types = array!(source, location).map.with_index do |value, index|
      type = string!(value, "#{location}[#{index}]", maximum: 100)
      prefix = type.split("/", 2).first
      expected = kind == "file" ? nil : kind
      if !type.match?(/\A[a-z0-9.+-]+\/[a-z0-9.+-]+\z/) || (expected && prefix != expected)
        raise Error, "#{location}[#{index}] is not an allowed #{kind} MIME type"
      end
      type
    end
    raise Error, "#{location} must define at least one MIME type" if types.empty?
    duplicate!(types, "MIME type in #{location}")
    types.freeze
  end

  def options!(source, kind:, location:)
    if kind == "select"
      source = hash!(source, location)
      raise Error, "#{location} must define at least one option" if source.empty?
      source.to_h do |id, labels|
        [ id!(id, "#{location} key"), localized_labels!(labels, "#{location}.#{id}") ]
      end.freeze
    else
      raise Error, "#{location} is only supported for select fields" unless source.nil?
      {}.freeze
    end
  end

  def build_taxonomies(source)
    items = array!(source, "taxonomies").map.with_index do |entry, index|
      location = "taxonomies[#{index}]"
      entry = hash!(entry, location)
      keys!(entry, TAXONOMY_KEYS, location)
      terms = build_terms(entry["terms"], location: "#{location}.terms")
      Taxonomy.new(
        id: id!(entry["id"], "#{location}.id"),
        position: index + 1,
        cardinality: enum!(entry["cardinality"], CARDINALITIES, "#{location}.cardinality"),
        filter: boolean!(entry["filter"], "#{location}.filter"),
        labels: localized_labels!(entry["labels"], "#{location}.labels"),
        terms:
      ).freeze
    end
    duplicate!(items.map(&:id), "taxonomy")
    items
  end

  def build_terms(source, location:)
    terms = array!(source, location).map.with_index do |entry, index|
      term_location = "#{location}[#{index}]"
      entry = hash!(entry, term_location)
      keys!(entry, TERM_KEYS, term_location)
      Term.new(
        id: id!(entry["id"], "#{term_location}.id"),
        position: index + 1,
        labels: localized_labels!(entry["labels"], "#{term_location}.labels")
      ).freeze
    end
    raise Error, "#{location} must define at least one term" if terms.empty?
    duplicate!(terms.map(&:id), "term in #{location}")
    terms.freeze
  end

  def build_items(source)
    entries = array!(source, "items").map.with_index do |entry, index|
      location = "items[#{index}]"
      entry = hash!(entry, location)
      keys!(entry, ITEM_KEYS, location)
      type = item_type(entry["item_type"])
      raise Error, "#{location}.item_type references unknown item type #{entry['item_type'].inspect}" unless type

      Item.new(
        id: id!(entry["id"], "#{location}.id"),
        position: index,
        item_type: type.id,
        published: boolean!(entry["published"], "#{location}.published"),
        translations: translations!(entry["translations"], "#{location}.translations"),
        fields: validate_fields!(entry["fields"], type:, location: "#{location}.fields"),
        taxonomies: taxonomy_selections!(entry["taxonomies"], "#{location}.taxonomies"),
        links: links!(entry["links"], "#{location}.links"),
        assets: assets!(entry["assets"], type:, location: "#{location}.assets")
      ).freeze
    end
    duplicate!(entries.map(&:id), "item")
    entries
  end

  def assets!(source, type:, location:)
    assets = array!(source, location).map.with_index do |entry, index|
      asset_location = "#{location}[#{index}]"
      entry = hash!(entry, asset_location)
      keys!(entry, ASSET_KEYS, asset_location)
      role = id!(entry["role"], "#{asset_location}.role")
      definition = type.media_role(role)
      raise Error, "#{asset_location}.role references unknown media role #{role.inspect}" unless definition

      Asset.new(
        role:,
        path: relative_asset_path!(entry["path"], "#{asset_location}.path"),
        alt: localized_labels!(entry["alt"], "#{asset_location}.alt")
      ).freeze
    end
    duplicate!(assets.map { |asset| [ asset.role, asset.path.to_s ] }, "asset in #{location}")
    assets.group_by(&:role).each do |role, selected|
      definition = type.media_role(role)
      if !definition.multiple && selected.many?
        raise Error, "#{location} media role #{role.inspect} accepts at most one asset"
      end
    end
    assets.freeze
  end

  def relative_asset_path!(value, location)
    relative = Pathname(string!(value, location, maximum: 500))
    if relative.absolute? || relative.each_filename.include?("..")
      raise Error, "#{location} must be relative and stay beside the Library manifest"
    end
    resolved = path.dirname.join(relative).cleanpath
    unless resolved.to_s.start_with?("#{path.dirname.cleanpath}/") && resolved.file?
      raise Error, "#{location} file does not exist: #{resolved}"
    end
    resolved.freeze
  end

  def translations!(source, location)
    source = hash!(source, location)
    unsupported = source.keys.map(&:to_s) - locales.available
    raise Error, "Unsupported locales in #{location}: #{unsupported.join(', ')}" if unsupported.any?

    translations = source.to_h do |locale, values|
      values = hash!(values, "#{location}.#{locale}")
      keys!(values, TRANSLATION_KEYS, "#{location}.#{locale}")
      [
        locale.to_s,
        TRANSLATION_KEYS.to_h do |field|
          [ field, text!(values[field], "#{location}.#{locale}.#{field}") ]
        end.freeze
      ]
    end
    fallback = translations[locales.fallback]
    unless fallback && TRANSLATION_KEYS.all? { |field| fallback[field].present? }
      raise Error, "#{location}.#{locales.fallback} must define title and summary"
    end
    translations.freeze
  end

  def validate_fields!(source, type:, location:)
    source = hash!(source || {}, location)
    unknown = source.keys.map(&:to_s) - type.fields.map(&:id)
    raise Error, "Unknown #{location} fields: #{unknown.join(', ')}" if unknown.any?

    normalized = type.fields.each_with_object({}) do |field, result|
      value = source[field.id]
      if value.nil?
        raise Error, "#{location}.#{field.id} is required" if field.required
        next
      end
      result[field.id] = field_value!(field, value, "#{location}.#{field.id}")
    end
    normalized.freeze
  end

  def field_value!(field, value, location)
    if field.localized
      localized_field_value!(field, value, location)
    elsif field.multiple?
      list = array!(value, location)
      raise Error, "#{location} must contain at least one value" if field.required && list.empty?
      list.map.with_index { |item, index| scalar!(field, item, "#{location}[#{index}]") }.freeze
    else
      scalar!(field, value, location)
    end
  end

  def localized_field_value!(field, value, location)
    value = hash!(value, location)
    unsupported = value.keys.map(&:to_s) - locales.available
    raise Error, "Unsupported locales in #{location}: #{unsupported.join(', ')}" if unsupported.any?

    normalized = value.to_h do |locale, localized_value|
      result = if field.multiple?
        array!(localized_value, "#{location}.#{locale}").map.with_index do |item, index|
          scalar!(field, item, "#{location}.#{locale}[#{index}]")
        end.freeze
      else
        scalar!(field, localized_value, "#{location}.#{locale}")
      end
      [ locale.to_s, result ]
    end
    if field.required && normalized[locales.fallback].blank?
      raise Error, "#{location}.#{locales.fallback} is required"
    end
    normalized.freeze
  end

  def scalar!(field, value, location)
    case field.kind
    when "string"
      string!(value, location, maximum: 500)
    when "text"
      string!(value, location, maximum: 50_000)
    when "url"
      url!(value, location)
    when "number"
      raise Error, "#{location} must be a finite number" unless value.is_a?(Numeric) && value.finite?
      value
    when "boolean"
      boolean!(value, location)
    when "select"
      option = id!(value, location)
      raise Error, "#{location} references unknown option #{option.inspect}" unless field.options.key?(option)
      option
    else
      raise Error, "Unsupported field kind #{field.kind.inspect}"
    end
  end

  def taxonomy_selections!(source, location)
    source = hash!(source || {}, location)
    unknown = source.keys.map(&:to_s) - taxonomy_ids
    raise Error, "Unknown #{location} taxonomies: #{unknown.join(', ')}" if unknown.any?

    source.to_h do |taxonomy_id, values|
      taxonomy = taxonomy(taxonomy_id)
      selected = array!(values, "#{location}.#{taxonomy_id}").map.with_index do |term_id, index|
        term_id = id!(term_id, "#{location}.#{taxonomy_id}[#{index}]")
        unless taxonomy.term(term_id)
          raise Error, "#{location}.#{taxonomy_id} references unknown term #{term_id.inspect}"
        end
        term_id
      end
      duplicate!(selected, "selection in #{location}.#{taxonomy_id}")
      if taxonomy.cardinality == "one" && selected.many?
        raise Error, "#{location}.#{taxonomy_id} accepts at most one term"
      end
      [ taxonomy_id.to_s, selected.freeze ]
    end.freeze
  end

  def links!(source, location)
    links = array!(source, location)
    raise Error, "#{location} accepts at most 20 links" if links.size > 20

    links.map.with_index do |entry, index|
      link_location = "#{location}[#{index}]"
      entry = hash!(entry, link_location)
      keys!(entry, LINK_KEYS, link_location)
      Link.new(
        label: string!(entry["label"], "#{link_location}.label", maximum: 200),
        url: url!(entry["url"], "#{link_location}.url")
      ).freeze
    end.freeze
  end

  def localized_labels!(source, location)
    source = hash!(source, location)
    unsupported = source.keys.map(&:to_s) - locales.available
    raise Error, "Unsupported locales in #{location}: #{unsupported.join(', ')}" if unsupported.any?
    unless source[locales.fallback].present?
      raise Error, "#{location}.#{locales.fallback} is required"
    end

    source.to_h do |locale, value|
      [ locale.to_s, string!(value, "#{location}.#{locale}", maximum: 200) ]
    end.freeze
  end

  def url!(value, location)
    url = string!(value, location, maximum: 2_000)
    uri = URI.parse(url)
    unless %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?
      raise Error, "#{location} must be an absolute HTTP or HTTPS URL without credentials"
    end
    url
  rescue URI::InvalidURIError
    raise Error, "#{location} must be a valid URL"
  end

  def id!(value, location)
    id = string!(value, location, maximum: 100)
    unless ID_FORMAT.match?(id)
      raise Error, "#{location} must use lowercase letters, numbers, hyphens, and underscores"
    end
    id
  end

  def string!(value, location, maximum:)
    raise Error, "#{location} must be a non-empty string" unless value.is_a?(String) && value.strip.present?
    normalized = value.strip
    raise Error, "#{location} is too long (maximum #{maximum} characters)" if normalized.length > maximum
    raise Error, "#{location} contains unsafe control characters" if normalized.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F]/)
    normalized.freeze
  end

  def text!(value, location)
    string!(value, location, maximum: 50_000)
  end

  def boolean!(value, location)
    raise Error, "#{location} must be true or false" unless value == true || value == false
    value
  end

  def enum!(value, supported, location)
    value = value.to_s
    raise Error, "#{location} must be one of: #{supported.join(', ')}" unless supported.include?(value)
    value.freeze
  end

  def hash!(value, location)
    raise Error, "#{location} must be a mapping" unless value.is_a?(Hash)
    value.transform_keys(&:to_s)
  end

  def array!(value, location)
    raise Error, "#{location} must be a list" unless value.is_a?(Array)
    value
  end

  def keys!(source, allowed, location)
    unknown = source.keys.map(&:to_s) - allowed
    raise Error, "Unknown #{location} keys: #{unknown.join(', ')}" if unknown.any?
  end

  def duplicate!(values, label)
    duplicate = values.group_by(&:itself).find { |_value, occurrences| occurrences.many? }&.first
    raise Error, "Duplicate #{label} id #{duplicate.inspect} in #{path}" if duplicate
  end
end
