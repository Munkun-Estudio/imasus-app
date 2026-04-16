class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :set_locale

  private

  # Sets I18n.locale from params, cookie, or default. Persists the choice
  # in a cookie so subsequent requests use the same locale.
  #
  # @param action [Proc] the controller action block (via around_action)
  # @return [void]
  def set_locale(&action)
    locale = params[:locale] || cookies[:locale] || I18n.default_locale
    locale = I18n.default_locale unless I18n.available_locales.include?(locale.to_sym)
    cookies[:locale] = { value: locale, expires: 1.year.from_now }
    I18n.with_locale(locale, &action)
  end
end
