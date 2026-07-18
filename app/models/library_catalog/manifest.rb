require "pathname"
require "uri"
require "yaml"

# Strict, non-executable contract for an installation's reusable Library.
class LibraryCatalog::Manifest
  class Error < StandardError; end

  Field = Data.define(
    :id, :kind, :localized, :required, :cardinality, :labels, :options
  ) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end

    def multiple?
      cardinality == "many"
    end
  end

  ItemType = Data.define(:id, :position, :labels, :fields) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end

    def field(id)
      fields.find { |candidate| candidate.id == id.to_s }
    end
  end

  Term = Data.define(:id, :position, :labels) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end
  end

  Taxonomy = Data.define(:id, :position, :cardinality, :labels, :terms) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end

    def term(id)
      terms.find { |candidate| candidate.id == id.to_s }
    end
  end

  Link = Data.define(:label, :url)
  Item = Data.define(
    :id, :position, :item_type, :published, :translations, :fields,
    :taxonomies, :links
  )

  ID_FORMAT = /\A[a-z0-9]+(?:[a-z0-9_-]*[a-z0-9])?\z/
  FIELD_KINDS = %w[string text url number boolean select].freeze
  CARDINALITIES = %w[one many].freeze
  TOP_LEVEL_KEYS = %w[version resource item_types taxonomies items].freeze
  ITEM_TYPE_KEYS = %w[id labels fields].freeze
  FIELD_KEYS = %w[id kind localized required cardinality labels options].freeze
  TAXONOMY_KEYS = %w[id cardinality labels terms].freeze
  TERM_KEYS = %w[id labels].freeze
  ITEM_KEYS = %w[id item_type published translations fields taxonomies links].freeze
  TRANSLATION_KEYS = %w[title summary].freeze
  LINK_KEYS = %w[label url].freeze

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
      ItemType.new(
        id: id!(entry["id"], "#{location}.id"),
        position: index,
        labels: localized_labels!(entry["labels"], "#{location}.labels"),
        fields:
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
        options:
      ).freeze
    end
    duplicate!(fields.map(&:id), "field in #{location}")
    fields.freeze
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
        links: links!(entry["links"], "#{location}.links")
      ).freeze
    end
    duplicate!(entries.map(&:id), "item")
    entries
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
