require "pathname"
require "uri"
require "yaml"

# Loads and validates the installation-level profile selected by APP_PROFILE.
#
# Site configuration is intentionally separate from secrets. Checked-in profile
# files describe public identity, locales, optional modules, content locations,
# public URLs, and non-secret operational settings. Credentials and environment
# variables remain the source of truth for passwords, tokens, and service keys.
class SiteConfig
  class Error < StandardError; end

  Identity = Data.define(:name, :short_name, :organization, :description)
  Locales = Data.define(:available, :default, :fallback, :labels) do
    def label(locale)
      labels.fetch(locale.to_s)
    end

    def fallback_chain(locale)
      requested = locale.to_s
      i18n_fallbacks = if I18n.respond_to?(:fallbacks)
        Array(I18n.fallbacks[requested]).map(&:to_s)
      else
        []
      end

      ([ requested ] + i18n_fallbacks + [ fallback, default ] + available)
        .select { |candidate| available.include?(candidate) }
        .uniq
    end
  end
  Content = Data.define(:root, :guides)
  PublicUrls = Data.define(:application, :fallback, :project, :source, :support)
  Analytics = Data.define(:enabled, :script_url)
  Operations = Data.define(:analytics)
  BrandAssets = Data.define(
    :logo, :compact_mark, :email_logo, :og_image, :favicon_ico, :favicon_svg,
    :favicon_png, :apple_touch_icon, :web_manifest
  )
  BrandTheme = Data.define(:primary, :secondary, :accent, :success, :info, :soft)
  BrandEmail = Data.define(:from_name, :from_address)
  Brand = Data.define(:assets, :theme, :email)

  Modules = Data.define(:library, :guides, :prompts, :glossary) do
    def enabled?(key)
      key = key.to_sym
      members.include?(key) && public_send(key)
    end

    def enabled
      members.select { |key| public_send(key) }
    end
  end

  CURRENT_VERSION = 1
  DEFAULT_PROFILE = "imasus"
  PROFILE_FORMAT = /\A[a-z0-9]+(?:[a-z0-9_-]*[a-z0-9])?\z/

  attr_reader :profile, :profile_path, :version, :identity, :locales, :modules,
              :content, :public_urls, :operations, :brand

  def self.load(root:, env: ENV)
    root = Pathname(root).expand_path
    profile = env.fetch("APP_PROFILE", DEFAULT_PROFILE).to_s

    unless PROFILE_FORMAT.match?(profile)
      raise Error, "APP_PROFILE must contain only lowercase letters, numbers, underscores, and hyphens"
    end

    profile_path = root.join("config", "profiles", "#{profile}.yml")
    raise Error, "Site profile not found: #{profile_path}" unless profile_path.file?

    source = profile_path.read
    raise Error, "ERB is not supported in site profiles: #{profile_path}" if source.include?("<%")

    payload = YAML.safe_load(source, permitted_classes: [], aliases: false)
    Builder.new(root:, profile:, profile_path:, payload:).build
  rescue Psych::Exception => error
    raise Error, "Could not parse site profile #{profile_path}: #{error.message}"
  end

  def initialize(profile:, profile_path:, version:, identity:, locales:, modules:,
                 content:, public_urls:, operations:, brand:)
    @profile = profile.freeze
    @profile_path = profile_path.freeze
    @version = version
    @identity = identity.freeze
    @locales = locales.freeze
    @modules = modules.freeze
    @content = content.freeze
    @public_urls = public_urls.freeze
    @operations = operations.freeze
    @brand = brand.freeze
    freeze
  end

  def summary
    [
      "Profile: #{profile}",
      "Configuration: #{profile_path}",
      "Version: #{version}",
      "Application: #{identity.name}",
      "Locales: #{locales.available.join(', ')} (default: #{locales.default}; fallback: #{locales.fallback})",
      "Modules: #{modules.enabled.join(', ')}",
      "Content root: #{content.root}",
      "Guides: #{content.guides}",
      "Public URL: #{public_urls.application}",
      "Logo: #{brand.assets.logo || 'text fallback'}",
      "Analytics: #{operations.analytics.enabled ? 'enabled' : 'disabled'}"
    ]
  end

  class Builder
    TOP_LEVEL_KEYS = %w[version identity locales modules content public_urls operations brand].freeze
    IDENTITY_KEYS = %w[name short_name organization description].freeze
    LOCALE_KEYS = %w[available default fallback labels].freeze
    MODULE_KEYS = %w[library guides prompts glossary].freeze
    CONTENT_KEYS = %w[root guides].freeze
    PUBLIC_URL_KEYS = %w[application fallback project source support].freeze
    OPERATIONS_KEYS = %w[analytics].freeze
    ANALYTICS_KEYS = %w[enabled script_url].freeze
    BRAND_KEYS = %w[assets theme email].freeze
    BRAND_ASSET_KEYS = %w[
      logo compact_mark email_logo og_image favicon_ico favicon_svg favicon_png
      apple_touch_icon web_manifest
    ].freeze
    BRAND_THEME_KEYS = %w[primary secondary accent success info soft].freeze
    BRAND_EMAIL_KEYS = %w[from_name from_address].freeze
    SECRET_KEY_PATTERN = /\A(?:api_?key|password|secret|token|private_?key|access_?key)\z/i
    HEX_COLOR_FORMAT = /\A#[0-9a-f]{6}\z/i
    EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\z/

    def initialize(root:, profile:, profile_path:, payload:)
      @root = root
      @profile = profile
      @profile_path = profile_path
      @payload = payload
    end

    def build
      config = hash!(@payload, "configuration")
      keys!(config, TOP_LEVEL_KEYS, "configuration")
      reject_secret_keys!(config)

      version = integer!(config, "version", "configuration")
      unless version == CURRENT_VERSION
        raise Error, "Unsupported site profile version #{version.inspect}; expected #{CURRENT_VERSION}"
      end

      identity = build_identity(config)
      locales = build_locales(config)
      modules = build_modules(config)
      content = build_content(config)
      public_urls = build_public_urls(config)
      operations = build_operations(config)
      brand = build_brand(config)

      SiteConfig.new(
        profile: @profile,
        profile_path: @profile_path,
        version:,
        identity:,
        locales:,
        modules:,
        content:,
        public_urls:,
        operations:,
        brand:
      )
    end

    private

    def build_identity(config)
      values = section!(config, "identity", IDENTITY_KEYS)
      Identity.new(
        name: string!(values, "name", "identity"),
        short_name: string!(values, "short_name", "identity"),
        organization: string!(values, "organization", "identity"),
        description: string!(values, "description", "identity")
      )
    end

    def build_locales(config)
      values = section!(config, "locales", LOCALE_KEYS)
      available = array!(values, "available", "locales").map.with_index do |locale, index|
        nonempty_string!(locale, "locales.available[#{index}]")
      end

      raise Error, "locales.available must contain at least one locale" if available.empty?
      raise Error, "locales.available contains duplicate locales" if available.uniq.length != available.length

      default = string!(values, "default", "locales")
      unless available.include?(default)
        raise Error, "locales.default #{default.inspect} must be present in locales.available"
      end

      fallback = string!(values, "fallback", "locales")
      unless available.include?(fallback)
        raise Error, "locales.fallback #{fallback.inspect} must be present in locales.available"
      end

      label_values = hash!(fetch!(values, "labels", "locales"), "locales.labels")
      label_keys = label_values.keys.map(&:to_s)
      missing_labels = available - label_keys
      extra_labels = label_keys - available
      raise Error, "Missing locales.labels entries: #{missing_labels.join(', ')}" if missing_labels.any?
      raise Error, "Unknown locales.labels entries: #{extra_labels.join(', ')}" if extra_labels.any?

      labels = available.to_h do |locale|
        [ locale.freeze, string!(label_values, locale, "locales.labels").freeze ]
      end.freeze

      Locales.new(
        available: available.freeze,
        default: default.freeze,
        fallback: fallback.freeze,
        labels:
      )
    end

    def build_modules(config)
      values = section!(config, "modules", MODULE_KEYS)
      Modules.new(**MODULE_KEYS.to_h { |key| [ key.to_sym, boolean!(values, key, "modules") ] })
    end

    def build_content(config)
      values = section!(config, "content", CONTENT_KEYS)
      content_root = directory!(string!(values, "root", "content"), "content.root")
      guides = directory!(string!(values, "guides", "content"), "content.guides")

      unless inside?(guides, content_root)
        raise Error, "content.guides must be inside content.root"
      end

      Content.new(root: content_root.freeze, guides: guides.freeze)
    end

    def build_public_urls(config)
      values = section!(config, "public_urls", PUBLIC_URL_KEYS)
      PublicUrls.new(
        application: url!(values, "application", "public_urls"),
        fallback: url!(values, "fallback", "public_urls"),
        project: url!(values, "project", "public_urls"),
        source: url!(values, "source", "public_urls"),
        support: optional_external_url!(values, "support", "public_urls")
      )
    end

    def build_operations(config)
      values = section!(config, "operations", OPERATIONS_KEYS)
      analytics_values = section!(values, "analytics", ANALYTICS_KEYS, path: "operations")
      enabled = boolean!(analytics_values, "enabled", "operations.analytics")
      script_url = optional_url!(analytics_values, "script_url", "operations.analytics")

      if enabled && script_url.nil?
        raise Error, "operations.analytics.script_url is required when analytics is enabled"
      end

      Operations.new(analytics: Analytics.new(enabled:, script_url:).freeze)
    end

    def build_brand(config)
      values = section!(config, "brand", BRAND_KEYS)
      asset_values = section!(values, "assets", BRAND_ASSET_KEYS, path: "brand")
      theme_values = section!(values, "theme", BRAND_THEME_KEYS, path: "brand")
      email_values = section!(values, "email", BRAND_EMAIL_KEYS, path: "brand")

      assets = BrandAssets.new(
        **BRAND_ASSET_KEYS.to_h do |key|
          [ key.to_sym, optional_asset!(asset_values, key, "brand.assets") ]
        end
      ).freeze

      theme = BrandTheme.new(
        **BRAND_THEME_KEYS.to_h do |key|
          [ key.to_sym, color!(theme_values, key, "brand.theme") ]
        end
      ).freeze

      from_address = string!(email_values, "from_address", "brand.email")
      unless EMAIL_FORMAT.match?(from_address)
        raise Error, "brand.email.from_address must be a valid email address"
      end

      email = BrandEmail.new(
        from_name: string!(email_values, "from_name", "brand.email"),
        from_address: from_address.freeze
      ).freeze

      Brand.new(assets:, theme:, email:)
    end

    def section!(source, key, allowed_keys, path: "configuration")
      value = hash!(fetch!(source, key, path), "#{path}.#{key}")
      keys!(value, allowed_keys, "#{path}.#{key}")
      value
    end

    def keys!(source, allowed, path)
      unknown = source.keys.map(&:to_s) - allowed
      return if unknown.empty?

      noun = unknown.length == 1 ? "key" : "keys"
      raise Error, "Unknown #{path} #{noun}: #{unknown.sort.join(', ')}"
    end

    def reject_secret_keys!(value, path = "configuration")
      case value
      when Hash
        value.each do |key, nested|
          key = key.to_s
          if SECRET_KEY_PATTERN.match?(key)
            raise Error, "Secret-like key #{path}.#{key} is not allowed; use Rails credentials or environment variables"
          end
          reject_secret_keys!(nested, "#{path}.#{key}")
        end
      when Array
        value.each_with_index { |nested, index| reject_secret_keys!(nested, "#{path}[#{index}]") }
      end
    end

    def fetch!(source, key, path)
      return source[key] if source.key?(key)

      raise Error, "Missing required key #{path}.#{key}"
    end

    def string!(source, key, path)
      nonempty_string!(fetch!(source, key, path), "#{path}.#{key}")
    end

    def nonempty_string!(value, path)
      unless value.is_a?(String) && !value.strip.empty?
        raise Error, "#{path} must be a non-empty string"
      end

      value.strip
    end

    def integer!(source, key, path)
      value = fetch!(source, key, path)
      raise Error, "#{path}.#{key} must be an integer" unless value.is_a?(Integer)

      value
    end

    def boolean!(source, key, path)
      value = fetch!(source, key, path)
      return value if value == true || value == false

      raise Error, "#{path}.#{key} must be true or false"
    end

    def array!(source, key, path)
      value = fetch!(source, key, path)
      raise Error, "#{path}.#{key} must be an array" unless value.is_a?(Array)

      value
    end

    def hash!(value, path)
      raise Error, "#{path} must be a mapping" unless value.is_a?(Hash)

      value.transform_keys(&:to_s)
    end

    def url!(source, key, path)
      value = string!(source, key, path)
      uri = URI.parse(value)
      unless %w[http https].include?(uri.scheme) && uri.host && !uri.host.empty?
        raise Error, "#{path}.#{key} must be an absolute HTTP(S) URL"
      end

      value.freeze
    rescue URI::InvalidURIError
      raise Error, "#{path}.#{key} must be an absolute HTTP(S) URL"
    end

    def optional_url!(source, key, path)
      value = fetch!(source, key, path)
      return nil if value.nil?

      url!(source, key, path)
    end

    def optional_external_url!(source, key, path)
      value = fetch!(source, key, path)
      return nil if value.nil?

      value = nonempty_string!(value, "#{path}.#{key}")
      uri = URI.parse(value)
      valid = (%w[http https].include?(uri.scheme) && uri.host && !uri.host.empty?) ||
              (uri.scheme == "mailto" && !uri.opaque.to_s.empty?)
      raise Error, "#{path}.#{key} must be an absolute HTTP(S) or mailto URL" unless valid

      value.freeze
    rescue URI::InvalidURIError
      raise Error, "#{path}.#{key} must be an absolute HTTP(S) or mailto URL"
    end

    def optional_asset!(source, key, path)
      value = fetch!(source, key, path)
      return nil if value.nil?

      value = nonempty_string!(value, "#{path}.#{key}")
      public_asset = value.start_with?("/")
      relative = Pathname(public_asset ? value.delete_prefix("/") : value)
      if relative.absolute? || relative.each_filename.any? { |part| part == ".." }
        raise Error, "#{path}.#{key} must be a safe asset path"
      end

      base = public_asset ? @root.join("public") : @root.join("app/assets/images")
      resolved = base.join(relative).cleanpath
      unless inside?(resolved, base) && resolved.file?
        raise Error, "#{path}.#{key} asset does not exist: #{resolved}"
      end

      unless inside?(resolved.realpath, base.realpath)
        raise Error, "#{path}.#{key} must not resolve outside its asset directory"
      end

      value.freeze
    end

    def color!(source, key, path)
      value = string!(source, key, path)
      raise Error, "#{path}.#{key} must be a six-digit hexadecimal color" unless HEX_COLOR_FORMAT.match?(value)

      value.upcase.freeze
    end

    def directory!(value, path)
      relative = Pathname(value)
      raise Error, "#{path} must be relative to the application root" if relative.absolute?

      resolved = @root.join(relative).cleanpath
      unless inside?(resolved, @root)
        raise Error, "#{path} must stay inside the application root"
      end
      raise Error, "#{path} directory does not exist: #{resolved}" unless resolved.directory?

      canonical = resolved.realpath
      unless inside?(canonical, @root.realpath)
        raise Error, "#{path} must not resolve outside the application root"
      end

      canonical
    end

    def inside?(candidate, parent)
      candidate == parent || candidate.to_s.start_with?("#{parent}#{File::SEPARATOR}")
    end
  end
end
