require "pathname"
require "yaml"

# Validated, non-executable description of a Guides content collection.
class TrainingModule::Manifest
  class Error < StandardError; end

  SectionDefinition = Data.define(:id, :labels) do
    def label(locale:, locales:)
      locales.fallback_chain(locale).filter_map { |candidate| labels[candidate] }.first || labels.values.first
    end
  end

  Translation = Data.define(:locale, :title, :summary, :documents)
  Guide = Data.define(:id, :published, :cover, :translations)

  ID_FORMAT = /\A[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?\z/
  TOP_LEVEL_KEYS = %w[version about sections guides].freeze
  GUIDE_KEYS = %w[id published cover translations].freeze
  TRANSLATION_KEYS = %w[title summary documents].freeze
  SECTION_KEYS = %w[id labels].freeze

  attr_reader :root, :about_documents, :sections, :guides

  def self.load(root: TrainingModule.content_path, locales: Rails.configuration.site.locales)
    new(root:, locales:).load
  end

  def initialize(root:, locales:)
    @root = Pathname(root).expand_path
    @locales = locales
  end

  def load
    payload = parse_yaml(manifest_path, "manifest")
    hash!(payload, "manifest")
    keys!(payload, TOP_LEVEL_KEYS, "manifest")
    version!(payload)

    @sections = build_sections(payload["sections"]).freeze
    @about_documents = build_documents(payload["about"], "about").freeze
    @guides = build_guides(payload["guides"]).freeze
    self
  rescue Psych::Exception => error
    raise Error, "Could not parse guide manifest #{manifest_path}: #{error.message}"
  end

  def section(id)
    sections.find { |section| section.id == id.to_s }
  end

  private

  attr_reader :locales

  def manifest_path
    root.join(TrainingModule::MANIFEST_FILENAME)
  end

  def version!(payload)
    version = payload["version"]
    raise Error, "Guide manifest version must be 1; got #{version.inspect}" unless version == 1
  end

  def build_sections(source)
    array!(source, "sections").map.with_index do |entry, index|
      path = "sections[#{index}]"
      entry = hash!(entry, path)
      keys!(entry, SECTION_KEYS, path)
      id = id!(entry["id"], "#{path}.id")
      labels = localized_strings!(entry["labels"], "#{path}.labels", require_all: true)
      SectionDefinition.new(id:, labels: labels.freeze).freeze
    end.tap do |items|
      duplicate = duplicate_value(items.map(&:id))
      raise Error, "Duplicate guide section id #{duplicate.inspect}" if duplicate
      raise Error, "Guide manifest must define at least one section" if items.empty?
    end
  end

  def build_guides(source)
    array!(source, "guides").map.with_index do |entry, index|
      path = "guides[#{index}]"
      entry = hash!(entry, path)
      keys!(entry, GUIDE_KEYS, path)
      id = id!(entry["id"], "#{path}.id")
      published = boolean!(entry["published"], "#{path}.published")
      cover = public_asset!(entry["cover"], "#{path}.cover")
      translations = build_translations(entry["translations"], path, guide_id: id)
      if published && translations.empty?
        raise Error, "#{path}.translations must contain at least one configured locale for a published guide"
      end

      Guide.new(id:, published:, cover:, translations: translations.freeze).freeze
    end.tap do |items|
      duplicate = duplicate_value(items.map(&:id))
      raise Error, "Duplicate guide id #{duplicate.inspect}" if duplicate
    end
  end

  def build_translations(source, path, guide_id:)
    source = hash!(source, "#{path}.translations")
    reject_unsupported_locales!(source, "#{path}.translations")

    source.to_h do |locale, entry|
      locale = locale.to_s
      translation_path = "#{path}.translations.#{locale}"
      entry = hash!(entry, translation_path)
      keys!(entry, TRANSLATION_KEYS, translation_path)
      documents = build_documents(entry["documents"], "#{translation_path}.documents")
      missing_sections = sections.map(&:id) - documents.keys
      if missing_sections.any?
        raise Error, "Missing #{translation_path}.documents entries: #{missing_sections.join(', ')}"
      end

      documents.each do |section_id, document_path|
        validate_frontmatter!(document_path, guide_id:, locale:, section_id:)
      end

      translation = Translation.new(
        locale:,
        title: string!(entry["title"], "#{translation_path}.title"),
        summary: string!(entry["summary"], "#{translation_path}.summary"),
        documents:
      ).freeze
      [ locale, translation ]
    end
  end

  def build_documents(source, path)
    source = hash!(source, path)
    reject_unsupported_locales!(source, path) if path == "about"
    raise Error, "about must contain at least one configured locale" if path == "about" && source.empty?

    source.to_h do |key, value|
      key = key.to_s
      unless path == "about" || sections.any? { |section| section.id == key }
        raise Error, "Unknown #{path} section #{key.inspect}"
      end
      [ key, document!(value, "#{path}.#{key}") ]
    end.freeze
  end

  def validate_frontmatter!(path, guide_id:, locale:, section_id:)
    source = path.read
    return unless source.start_with?("---")

    parts = source.split(/^---\s*$\n?/, 3)
    frontmatter = parse_yaml_string(parts[1], path)
    hash!(frontmatter, "front matter in #{path.relative_path_from(root)}")
    {
      "module_slug" => guide_id,
      "lang" => locale,
      "volume" => section_id
    }.each do |key, expected|
      next unless frontmatter.key?(key)
      next if frontmatter[key] == expected

      relative = path.relative_path_from(root)
      raise Error, "Front matter #{key} in #{relative} must be #{expected.inspect}"
    end
  rescue Psych::Exception => error
    relative = path.relative_path_from(root)
    raise Error, "Malformed front matter in #{relative}: #{error.message}"
  end

  def document!(value, path)
    relative = string!(value, path)
    candidate = Pathname(relative)
    if candidate.absolute? || candidate.each_filename.any? { |part| part == ".." }
      raise Error, "#{path} must be a safe path inside #{root}"
    end

    expanded = root.join(candidate).expand_path
    unless expanded.to_s.start_with?("#{root}/")
      raise Error, "#{path} must be a safe path inside #{root}"
    end
    raise Error, "Missing guide document #{relative.inspect} referenced by #{path}" unless expanded.file?
    unless expanded.realpath.to_s.start_with?("#{root.realpath}/")
      raise Error, "#{path} resolves outside #{root}"
    end

    validate_yaml_frontmatter!(expanded)
    expanded.freeze
  end

  def validate_yaml_frontmatter!(path)
    source = path.read
    return unless source.start_with?("---")

    parts = source.split(/^---\s*$\n?/, 3)
    relative = path.relative_path_from(root)
    raise Error, "Unclosed front matter in #{relative}" if parts.length < 3

    frontmatter = parse_yaml_string(parts[1], relative)
    hash!(frontmatter, "front matter in #{relative}")
  end

  def public_asset!(value, path)
    asset = string!(value, path)
    unless asset.start_with?("/") && !asset.include?("..") && !asset.start_with?("//")
      raise Error, "#{path} must be a safe application-relative URL"
    end
    public_path = Rails.root.join("public", asset.delete_prefix("/"))
    raise Error, "Missing guide cover #{asset.inspect} referenced by #{path}" unless public_path.file?

    asset.freeze
  end

  def localized_strings!(source, path, require_all:)
    source = hash!(source, path)
    reject_unsupported_locales!(source, path)
    missing = locales.available - source.keys.map(&:to_s)
    raise Error, "Missing #{path} entries: #{missing.join(', ')}" if require_all && missing.any?

    source.to_h { |locale, value| [ locale.to_s, string!(value, "#{path}.#{locale}") ] }
  end

  def reject_unsupported_locales!(source, path)
    unsupported = source.keys.map(&:to_s) - locales.available
    raise Error, "Unsupported locales in #{path}: #{unsupported.join(', ')}" if unsupported.any?
  end

  def parse_yaml(path, label)
    raise Error, "Missing guide #{label} at #{path}" unless path.file?
    parse_yaml_string(path.read, path)
  end

  def parse_yaml_string(source, path)
    YAML.safe_load(source, permitted_classes: [], aliases: false) || {}
  rescue Psych::Exception => error
    raise Error, "Could not parse YAML in #{path}: #{error.message}"
  end

  def keys!(source, allowed, path)
    unknown = source.keys.map(&:to_s) - allowed
    raise Error, "Unknown #{path} keys: #{unknown.join(', ')}" if unknown.any?
  end

  def hash!(value, path)
    raise Error, "#{path} must be a mapping" unless value.is_a?(Hash)
    value
  end

  def array!(value, path)
    raise Error, "#{path} must be a list" unless value.is_a?(Array)
    value
  end

  def string!(value, path)
    raise Error, "#{path} must be a non-empty string" unless value.is_a?(String) && value.strip.present?
    value.strip
  end

  def boolean!(value, path)
    raise Error, "#{path} must be true or false" unless value == true || value == false
    value
  end

  def id!(value, path)
    id = string!(value, path)
    raise Error, "#{path} must use lowercase letters, numbers, and hyphens" unless ID_FORMAT.match?(id)
    id
  end

  def duplicate_value(values)
    values.group_by(&:itself).find { |_value, occurrences| occurrences.length > 1 }&.first
  end
end
