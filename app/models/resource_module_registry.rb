class ResourceModuleRegistry
  ResourceModule = Data.define(
    :key, :legacy_key, :enabled, :labels, :route_helper, :controllers,
    :content_source, :bookmark_type, :legacy_bookmark_types, :bookmark_preview, :number, :color,
    :card_classes, :lead_i18n_key, :dependencies
  ) do
    def enabled?
      enabled
    end

    def bookmarkable?
      bookmark_type.present?
    end

    def bookmark_types
      [ bookmark_type, *legacy_bookmark_types ].compact
    end

    def label(locale: I18n.locale, locales:)
      locales.fallback_chain(locale).each do |candidate|
        value = labels[candidate]
        return value if value.present?
      end

      labels.values.find(&:present?)
    end
  end

  DEFINITIONS = {
    library: {
      legacy_key: "materials",
      route_helper: :materials_path,
      controllers: %w[materials],
      content_source: { type: :database, identifier: "library_items" },
      bookmark_type: "LibraryItem",
      legacy_bookmark_types: %w[Material],
      bookmark_preview: nil,
      number: "02",
      color: "bg-brand-info",
      card_classes: "border-brand-primary/10 bg-brand-info/30 hover:bg-brand-info/50",
      lead_i18n_key: "home.visitor.resources.materials.lead",
      dependencies: []
    },
    guides: {
      legacy_key: "training",
      route_helper: :training_index_path,
      controllers: %w[training],
      content_source: { type: :filesystem, identifier: "content.guides" },
      bookmark_type: "TrainingModule",
      legacy_bookmark_types: [],
      bookmark_preview: :training_image,
      number: "03",
      color: "bg-brand-secondary",
      card_classes: "border-brand-secondary/10 bg-brand-secondary text-white hover:brightness-110",
      lead_i18n_key: "home.visitor.resources.training.lead",
      dependencies: []
    },
    prompts: {
      legacy_key: "challenges",
      route_helper: :challenges_path,
      controllers: %w[challenges],
      content_source: { type: :database, identifier: "challenges" },
      bookmark_type: "Challenge",
      legacy_bookmark_types: [],
      bookmark_preview: nil,
      number: "04",
      color: "bg-brand-success",
      card_classes: "border-brand-primary/10 bg-brand-success/40 hover:bg-brand-success/60",
      lead_i18n_key: "home.visitor.resources.challenges.lead",
      dependencies: []
    },
    glossary: {
      legacy_key: "glossary",
      route_helper: :glossary_terms_path,
      controllers: %w[glossary_terms],
      content_source: { type: :database, identifier: "glossary_terms" },
      bookmark_type: "GlossaryTerm",
      legacy_bookmark_types: [],
      bookmark_preview: nil,
      number: "05",
      color: "bg-brand-soft",
      card_classes: "border-brand-primary/10 bg-brand-soft/40 hover:bg-brand-soft/60",
      lead_i18n_key: "home.visitor.resources.glossary.lead",
      dependencies: []
    }
  }.freeze

  def self.current
    new(Rails.configuration.site)
  end

  def initialize(site_config, definitions: DEFINITIONS)
    @site_config = site_config
    @definitions = definitions
    validate!
  end

  def all
    @all ||= @definitions.map do |key, metadata|
      ResourceModule.new(
        key:,
        enabled: @site_config.modules.enabled?(key),
        labels: @site_config.modules.labels.fetch(key),
        **metadata
      )
    end.freeze
  end

  def enabled
    all.select(&:enabled?)
  end

  def fetch(key)
    all.find { |resource_module| resource_module.key == key.to_sym } ||
      raise(KeyError, "Unknown resource module #{key.inspect}")
  end

  def enabled?(key)
    fetch(key).enabled?
  end

  def for_bookmark_type(type)
    all.find { |resource_module| resource_module.bookmark_types.include?(type.to_s) }
  end

  def enabled_bookmark_types
    enabled.flat_map(&:bookmark_types)
  end

  private

  def validate!
    unknown = @site_config.modules.enabled - @definitions.keys
    raise ArgumentError, "Unknown enabled resource modules: #{unknown.join(', ')}" if unknown.any?

    @definitions.each do |key, metadata|
      Array(metadata.fetch(:dependencies)).each do |dependency|
        unless @definitions.key?(dependency)
          raise ArgumentError, "Resource module #{key} has unknown dependency #{dependency}"
        end
        next unless @site_config.modules.enabled?(key)
        next if @site_config.modules.enabled?(dependency)

        raise ArgumentError, "Resource module #{key} requires enabled module #{dependency}"
      end
    end
  end
end
