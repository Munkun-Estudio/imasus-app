require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class SiteConfigTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir("site-config-test"))
    @root.join("config/profiles").mkpath
    @root.join("content/guides").mkpath
    @root.join("app/assets/images").mkpath
    @root.join("public").mkpath
    %w[logo.svg og-image.png].each { |name| @root.join("app/assets/images", name).write("asset") }
    %w[
      icon.svg icon.png favicon.ico favicon.svg favicon-96x96.png
      apple-touch-icon.png site.webmanifest
    ].each { |name| @root.join("public", name).write("asset") }
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "loads a selected profile into immutable typed values" do
    write_profile("custom")

    config = SiteConfig.load(root: @root, env: { "APP_PROFILE" => "custom" })

    assert_equal "custom", config.profile
    assert_equal 1, config.version
    assert_equal "Example App", config.identity.name
    assert_equal "Example workshops.", config.identity.description
    assert_equal %w[en es], config.locales.available
    assert_equal "en", config.locales.default
    assert_equal "en", config.locales.fallback
    assert_equal "Español", config.locales.label(:es)
    assert_equal %w[es en], config.locales.fallback_chain(:es).first(2)
    assert config.modules.library
    assert_not config.modules.glossary
    assert_equal %i[library guides prompts], config.modules.enabled
    assert_equal "Materiales", config.modules.labels.fetch(:library).fetch("es")
    assert_equal @root.join("content").realpath, config.content.root
    assert_equal @root.join("content/guides").realpath, config.content.guides
    assert_equal "https://example.test", config.public_urls.application
    assert_equal "mailto:help@example.test", config.public_urls.support
    assert_equal "logo.svg", config.brand.assets.logo
    assert_equal "#123456", config.brand.theme.primary
    assert_equal "Example <no-reply@example.test>",
                 "#{config.brand.email.from_name} <#{config.brand.email.from_address}>"
    assert config.operations.analytics.enabled
    assert config.frozen?
    assert config.identity.frozen?
    assert config.locales.available.frozen?
    assert_raises(FrozenError) { config.locales.available << "it" }
  end

  test "uses the imasus profile by default" do
    write_profile("imasus")

    config = SiteConfig.load(root: @root, env: {})

    assert_equal "imasus", config.profile
  end

  test "rails exposes the default profile through one configuration API" do
    config = Rails.configuration.site

    assert_instance_of SiteConfig, config
    assert_equal "imasus", config.profile
    assert_equal %w[en es it el], config.locales.available
    assert_equal config.locales.available.map(&:to_sym), I18n.available_locales
    assert_equal config.locales.default.to_sym, I18n.default_locale
    assert_equal "en", config.locales.fallback
    assert_equal "Ελληνικά", config.locales.label(:el)
  end

  test "rejects unsafe profile names" do
    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "../production" })
    end

    assert_includes error.message, "APP_PROFILE"
  end

  test "reports a missing profile path" do
    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "missing" })
    end

    assert_includes error.message, "config/profiles/missing.yml"
  end

  test "rejects unsupported contract versions" do
    write_profile("future", payload: valid_profile.merge("version" => 2))

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "future" })
    end

    assert_includes error.message, "Unsupported site profile version 2"
  end

  test "reports missing required keys" do
    payload = valid_profile
    payload["identity"].delete("organization")
    write_profile("missing-key", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "missing-key" })
    end

    assert_includes error.message, "Missing required key identity.organization"
  end

  test "rejects unknown keys at every contract level" do
    payload = valid_profile
    payload["identity"]["tagline"] = "Unexpected"
    write_profile("unknown", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "unknown" })
    end

    assert_includes error.message, "Unknown configuration.identity key: tagline"
  end

  test "rejects secret-like keys" do
    payload = valid_profile
    payload["operations"]["api_key"] = "do-not-store-this"
    write_profile("secret", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "secret" })
    end

    assert_includes error.message, "Secret-like key configuration.operations.api_key"
  end

  test "requires the default locale to be available" do
    payload = valid_profile
    payload["locales"]["default"] = "it"
    write_profile("bad-locale", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "bad-locale" })
    end

    assert_includes error.message, "must be present in locales.available"
  end

  test "requires the fallback locale to be available" do
    payload = valid_profile
    payload["locales"]["fallback"] = "it"
    write_profile("bad-fallback", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "bad-fallback" })
    end

    assert_includes error.message, "locales.fallback"
    assert_includes error.message, "must be present in locales.available"
  end

  test "requires one display label for every configured locale" do
    payload = valid_profile
    payload["locales"]["labels"].delete("es")
    write_profile("missing-label", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "missing-label" })
    end

    assert_includes error.message, "Missing locales.labels entries: es"
  end

  test "supports a single-locale installation" do
    payload = valid_profile
    payload["locales"] = {
      "available" => [ "es" ],
      "default" => "es",
      "fallback" => "es",
      "labels" => { "es" => "Español" }
    }
    payload["modules"]["labels"].each_value do |labels|
      labels.replace("es" => labels.fetch("es"))
    end
    write_profile("single-locale", payload:)

    config = SiteConfig.load(root: @root, env: { "APP_PROFILE" => "single-locale" })

    assert_equal [ "es" ], config.locales.available
    assert_equal [ "es" ], config.locales.fallback_chain(:es)
  end

  test "preserves configured ordering when an additional locale is added" do
    payload = valid_profile
    payload["locales"] = {
      "available" => %w[fr en es],
      "default" => "fr",
      "fallback" => "en",
      "labels" => {
        "fr" => "Français",
        "en" => "English",
        "es" => "Español"
      }
    }
    payload["modules"]["labels"].each_value do |labels|
      labels["fr"] = "Français"
      labels.replace(
        "fr" => labels.fetch("fr"),
        "en" => labels.fetch("en"),
        "es" => labels.fetch("es")
      )
    end
    write_profile("additional-locale", payload:)

    config = SiteConfig.load(root: @root, env: { "APP_PROFILE" => "additional-locale" })

    assert_equal %w[fr en es], config.locales.available
    assert_equal "Français", config.locales.label(:fr)
    assert_equal %w[fr en es], config.locales.fallback_chain(:fr)
  end

  test "requires explicit boolean module flags" do
    payload = valid_profile
    payload["modules"]["guides"] = "yes"
    write_profile("bad-module", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "bad-module" })
    end

    assert_includes error.message, "modules.guides must be true or false"
  end

  test "requires localized labels for every supported module" do
    payload = valid_profile
    payload["modules"]["labels"]["library"].delete("es")
    write_profile("missing-module-label", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "missing-module-label" })
    end

    assert_includes error.message, "Missing modules.labels.library entries: es"
  end

  test "rejects content paths outside the application root" do
    payload = valid_profile
    payload["content"]["root"] = "../content"
    write_profile("unsafe-path", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "unsafe-path" })
    end

    assert_includes error.message, "must stay inside the application root"
  end

  test "reports missing content directories" do
    payload = valid_profile
    payload["content"]["guides"] = "content/missing"
    write_profile("missing-content", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "missing-content" })
    end

    assert_includes error.message, "content.guides directory does not exist"
  end

  test "rejects content symlinks that resolve outside the application root" do
    outside = Pathname(Dir.mktmpdir("site-config-outside"))
    FileUtils.rm_rf(@root.join("content/guides"))
    FileUtils.ln_s(outside, @root.join("content/guides"))
    write_profile("symlink")

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "symlink" })
    end

    assert_includes error.message, "must not resolve outside the application root"
  ensure
    FileUtils.remove_entry(outside) if outside&.exist?
  end

  test "requires absolute HTTP or HTTPS public URLs" do
    payload = valid_profile
    payload["public_urls"]["application"] = "/relative"
    write_profile("bad-url", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "bad-url" })
    end

    assert_includes error.message, "must be an absolute HTTP(S) URL"
  end

  test "allows analytics to be disabled without a script URL" do
    payload = valid_profile
    payload["operations"]["analytics"] = { "enabled" => false, "script_url" => nil }
    write_profile("no-analytics", payload:)

    config = SiteConfig.load(root: @root, env: { "APP_PROFILE" => "no-analytics" })

    assert_not config.operations.analytics.enabled
    assert_nil config.operations.analytics.script_url
  end

  test "allows optional brand assets and support links to be absent" do
    payload = valid_profile
    payload["brand"]["assets"].transform_values! { nil }
    payload["public_urls"]["support"] = nil
    write_profile("minimal-brand", payload:)

    config = SiteConfig.load(root: @root, env: { "APP_PROFILE" => "minimal-brand" })

    assert_nil config.brand.assets.logo
    assert_nil config.brand.assets.favicon_svg
    assert_nil config.public_urls.support
  end

  test "rejects missing brand asset files" do
    payload = valid_profile
    payload["brand"]["assets"]["logo"] = "missing.svg"
    write_profile("missing-brand-asset", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "missing-brand-asset" })
    end

    assert_includes error.message, "brand.assets.logo asset does not exist"
  end

  test "rejects brand asset symlinks outside the asset directory" do
    outside = Pathname(Dir.mktmpdir("site-config-brand-outside")).join("logo.svg")
    outside.write("asset")
    FileUtils.rm_f(@root.join("app/assets/images/logo.svg"))
    FileUtils.ln_s(outside, @root.join("app/assets/images/logo.svg"))
    write_profile("unsafe-brand-asset")

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "unsafe-brand-asset" })
    end

    assert_includes error.message, "must not resolve outside its asset directory"
  ensure
    FileUtils.remove_entry(outside.dirname) if outside&.dirname&.exist?
  end

  test "rejects arbitrary theme values" do
    payload = valid_profile
    payload["brand"]["theme"]["primary"] = "expression(alert(1))"
    write_profile("unsafe-theme", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "unsafe-theme" })
    end

    assert_includes error.message, "must be a six-digit hexadecimal color"
  end

  test "rejects invalid default email addresses" do
    payload = valid_profile
    payload["brand"]["email"]["from_address"] = "not-an-email"
    write_profile("bad-email", payload:)

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "bad-email" })
    end

    assert_includes error.message, "must be a valid email address"
  end

  test "rejects ERB instead of executing profile code" do
    @root.join("config/profiles/erb.yml").write("version: <%= 1 %>\n")

    error = assert_raises(SiteConfig::Error) do
      SiteConfig.load(root: @root, env: { "APP_PROFILE" => "erb" })
    end

    assert_includes error.message, "ERB is not supported"
  end

  test "standalone diagnostic succeeds for the default profile" do
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      Rails.root.join("bin/site-config").to_s,
      chdir: Rails.root.to_s
    )

    assert status.success?, stderr
    assert_includes stdout, "Site configuration is valid."
    assert_includes stdout, "Profile: imasus"
  end

  test "standalone diagnostic exits non-zero for an invalid profile" do
    stdout, stderr, status = Open3.capture3(
      { "APP_PROFILE" => "missing" },
      RbConfig.ruby,
      Rails.root.join("bin/site-config").to_s,
      chdir: Rails.root.to_s
    )

    assert_not status.success?
    assert_empty stdout
    assert_includes stderr, "Site configuration is invalid."
    assert_includes stderr, "config/profiles/missing.yml"
  end

  private

  def write_profile(name, payload: valid_profile)
    @root.join("config/profiles/#{name}.yml").write(YAML.dump(payload))
  end

  def valid_profile
    {
      "version" => 1,
      "identity" => {
        "name" => "Example App",
        "short_name" => "Example",
        "organization" => "Example Organisation",
        "description" => "Example workshops."
      },
      "locales" => {
        "available" => %w[en es],
        "default" => "en",
        "fallback" => "en",
        "labels" => {
          "en" => "English",
          "es" => "Español"
        }
      },
      "modules" => {
        "library" => true,
        "guides" => true,
        "prompts" => true,
        "glossary" => false,
        "labels" => {
          "library" => { "en" => "Materials", "es" => "Materiales" },
          "guides" => { "en" => "Training", "es" => "Formación" },
          "prompts" => { "en" => "Challenges", "es" => "Retos" },
          "glossary" => { "en" => "Glossary", "es" => "Glosario" }
        }
      },
      "content" => {
        "root" => "content",
        "guides" => "content/guides"
      },
      "public_urls" => {
        "application" => "https://example.test",
        "fallback" => "https://fallback.example.test",
        "project" => "https://project.example.test",
        "source" => "https://github.com/example/project",
        "support" => "mailto:help@example.test"
      },
      "operations" => {
        "analytics" => {
          "enabled" => true,
          "script_url" => "https://stats.example.test/script.js"
        }
      },
      "brand" => {
        "assets" => {
          "logo" => "logo.svg",
          "compact_mark" => "/icon.svg",
          "email_logo" => "/icon.png",
          "og_image" => "og-image.png",
          "favicon_ico" => "/favicon.ico",
          "favicon_svg" => "/favicon.svg",
          "favicon_png" => "/favicon-96x96.png",
          "apple_touch_icon" => "/apple-touch-icon.png",
          "web_manifest" => "/site.webmanifest"
        },
        "theme" => {
          "primary" => "#123456",
          "secondary" => "#234567",
          "accent" => "#345678",
          "success" => "#456789",
          "info" => "#56789A",
          "soft" => "#6789AB"
        },
        "email" => {
          "from_name" => "Example",
          "from_address" => "no-reply@example.test"
        }
      }
    }
  end
end
