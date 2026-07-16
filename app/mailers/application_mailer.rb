class ApplicationMailer < ActionMailer::Base
  default from: -> {
    email = Rails.configuration.site.brand.email
    ENV.fetch("MAILER_FROM", "#{email.from_name} <#{email.from_address}>")
  }
  layout "mailer"

  helper_method :site_config, :site_name, :site_short_name, :site_translation_options

  def site_config
    Rails.configuration.site
  end

  def site_name
    site_config.identity.name
  end

  def site_short_name
    site_config.identity.short_name
  end

  def site_translation_options
    {
      app_name: site_name,
      short_name: site_short_name,
      organization: site_config.identity.organization
    }
  end
end
