require "pathname"
require "yaml"

# Strict, non-executable manifest for database-backed resource catalogues.
class ResourceCatalog::Manifest
  class Error < StandardError; end

  Category = Data.define(:id, :position, :labels) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end
  end
  Entry = Data.define(:id, :position, :category, :tags, :published, :asset, :translations)

  ID_FORMAT = /\A[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?\z/i
  TOP_LEVEL_KEYS = %w[version resource categories entries].freeze
  CATEGORY_KEYS = %w[id labels].freeze
  ENTRY_KEYS = %w[id category tags published asset translations].freeze

  attr_reader :path, :resource, :categories, :entries

  def self.load(path:, resource:, fields:, optional_fields: [])
    new(path:, resource:, fields:, optional_fields:).load
  end

  def initialize(path:, resource:, fields:, optional_fields: [])
    @path = Pathname(path)
    @resource = resource.to_s
    @fields = fields.stringify_keys
    @optional_fields = optional_fields.map(&:to_s)
    @locales = Rails.configuration.site.locales
  end

  def load
    payload = YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}
    payload = hash!(payload, "manifest")
    keys!(payload, TOP_LEVEL_KEYS, "manifest")
    raise Error, "#{path} version must be 1" unless payload["version"] == 1
    unless payload["resource"] == resource
      raise Error, "#{path} resource must be #{resource.inspect}"
    end

    @categories = build_categories(payload["categories"]).freeze
    @entries = build_entries(payload["entries"]).freeze
    self
  rescue Psych::Exception => error
    raise Error, "Could not parse #{path}: #{error.message}"
  end

  def category(id)
    categories.find { |candidate| candidate.id == id.to_s }
  end

  def category_ids
    categories.map(&:id)
  end

  private

  attr_reader :fields, :optional_fields, :locales

  def build_categories(source)
    array!(source, "categories").map.with_index do |entry, index|
      location = "categories[#{index}]"
      entry = hash!(entry, location)
      keys!(entry, CATEGORY_KEYS, location)
      id = id!(entry["id"], "#{location}.id").downcase
      labels = localized_labels!(entry["labels"], "#{location}.labels")
      Category.new(id:, position: index + 1, labels: labels.freeze).freeze
    end.tap do |items|
      raise Error, "#{path} must define at least one category" if items.empty?
      duplicate = duplicate_value(items.map(&:id))
      raise Error, "Duplicate category id #{duplicate.inspect} in #{path}" if duplicate
    end
  end

  def build_entries(source)
    array!(source, "entries").map.with_index do |entry, index|
      location = "entries[#{index}]"
      entry = hash!(entry, location)
      keys!(entry, ENTRY_KEYS, location)
      id = id!(entry["id"], "#{location}.id")
      category = id!(entry["category"], "#{location}.category").downcase
      unless category_ids.include?(category)
        raise Error, "#{location}.category references unknown category #{category.inspect}"
      end

      Entry.new(
        id:,
        position: index + 1,
        category:,
        tags: tags!(entry["tags"], "#{location}.tags"),
        published: boolean!(entry["published"], "#{location}.published"),
        asset: asset!(entry["asset"], "#{location}.asset"),
        translations: translations!(entry["translations"], location)
      ).freeze
    end.tap do |items|
      duplicate = duplicate_value(items.map { |entry| entry.id.downcase })
      raise Error, "Duplicate entry id #{duplicate.inspect} in #{path}" if duplicate
    end
  end

  def translations!(source, location)
    source = hash!(source, "#{location}.translations")
    unsupported = source.keys.map(&:to_s) - locales.available
    if unsupported.any?
      raise Error, "Unsupported locales in #{location}.translations: #{unsupported.join(', ')}"
    end

    fallback = locales.fallback
    fallback_content = source[fallback]
    unless fallback_content.is_a?(Hash)
      raise Error, "#{location}.translations.#{fallback} is required"
    end

    translations = source.to_h do |locale, values|
      locale = locale.to_s
      values = hash!(values, "#{location}.translations.#{locale}")
      keys!(values, fields.keys, "#{location}.translations.#{locale}")
      normalized = values.to_h do |field, value|
        [ field.to_s, field_value!(field.to_s, value, "#{location}.translations.#{locale}.#{field}") ]
      end
      [ locale, normalized.freeze ]
    end

    (fields.keys - optional_fields).each do |field|
      value = translations.dig(fallback, field)
      unless value.respond_to?(:present?) && value.present?
        raise Error, "#{location}.translations.#{fallback}.#{field} is required"
      end
    end
    translations.freeze
  end

  def localized_labels!(source, location)
    source = hash!(source, location)
    unsupported = source.keys.map(&:to_s) - locales.available
    raise Error, "Unsupported locales in #{location}: #{unsupported.join(', ')}" if unsupported.any?
    missing = locales.available - source.keys.map(&:to_s)
    raise Error, "Missing #{location} entries: #{missing.join(', ')}" if missing.any?

    source.to_h { |locale, value| [ locale.to_s, string!(value, "#{location}.#{locale}") ] }
  end

  def field_value!(field, value, location)
    case fields.fetch(field)
    when :string
      string!(value, location)
    when :array
      array!(value, location).map.with_index { |item, index| string!(item, "#{location}[#{index}]") }.freeze
    else
      raise Error, "Unsupported field contract #{fields.fetch(field).inspect}"
    end
  end

  def asset!(value, location)
    return nil if value.nil?
    asset = string!(value, location)
    unless asset.start_with?("/") && !asset.start_with?("//") && !asset.include?("..")
      raise Error, "#{location} must be a safe application-relative URL"
    end
    public_path = Rails.root.join("public", asset.delete_prefix("/"))
    raise Error, "Missing asset #{asset.inspect} referenced by #{location}" unless public_path.file?
    asset.freeze
  end

  def tags!(value, location)
    return [].freeze if value.nil?

    tags = array!(value, location).map.with_index do |tag, index|
      id!(tag, "#{location}[#{index}]").downcase
    end
    duplicate = duplicate_value(tags)
    raise Error, "Duplicate tag #{duplicate.inspect} in #{location}" if duplicate
    tags.freeze
  end

  def hash!(value, location)
    raise Error, "#{location} must be a mapping" unless value.is_a?(Hash)
    value.transform_keys(&:to_s)
  end

  def array!(value, location)
    raise Error, "#{location} must be a list" unless value.is_a?(Array)
    value
  end

  def string!(value, location)
    raise Error, "#{location} must be a non-empty string" unless value.is_a?(String) && value.strip.present?
    value.strip
  end

  def boolean!(value, location)
    raise Error, "#{location} must be true or false" unless value == true || value == false
    value
  end

  def id!(value, location)
    id = string!(value, location)
    raise Error, "#{location} must use letters, numbers, and hyphens" unless ID_FORMAT.match?(id)
    id
  end

  def keys!(source, allowed, location)
    unknown = source.keys.map(&:to_s) - allowed
    raise Error, "Unknown #{location} keys: #{unknown.join(', ')}" if unknown.any?
  end

  def duplicate_value(values)
    values.group_by(&:itself).find { |_value, occurrences| occurrences.many? }&.first
  end
end
