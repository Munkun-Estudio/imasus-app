module SiteI18nInterpolation
  def translate(locale, key, options = I18n::EMPTY_HASH)
    site = Rails.configuration.site
    analytics_url = site.operations.analytics.script_url
    site_values = {
      app_name: site.identity.name,
      short_name: site.identity.short_name,
      organization: site.identity.organization,
      project_url: site.public_urls.project,
      analytics_host: analytics_url && URI.parse(analytics_url).host
    }

    super(locale, key, site_values.merge(options))
  end
end

I18n.backend.singleton_class.prepend(SiteI18nInterpolation)
