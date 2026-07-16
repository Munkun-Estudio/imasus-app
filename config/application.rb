require_relative "boot"

require "rails/all"
require_relative "../lib/site_config"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ImasusApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.site = SiteConfig.load(root: Pathname(__dir__).join(".."))
    config.i18n.available_locales = config.site.locales.available.map(&:to_sym)
    config.i18n.default_locale = config.site.locales.default.to_sym
    config.i18n.fallbacks = config.site.locales.available.to_h do |locale|
      [ locale.to_sym, [ config.site.locales.fallback.to_sym ] ]
    end

    # Direct public URLs — Tigris serves files from its CDN, no Rails proxy needed.
    config.active_storage.resolve_model_to_route = :rails_storage_redirect
    config.active_storage.variant_processor = :mini_magick
  end
end
