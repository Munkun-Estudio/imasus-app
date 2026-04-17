class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :set_locale

  helper_method :current_user, :logged_in?, :curator?

  # True when the signed-in user may curate shared content (admin or facilitator).
  #
  # @return [Boolean]
  def curator?
    logged_in? && %w[admin facilitator].include?(current_user.role)
  end

  # Returns the signed-in user for the current request, or nil. Memoised.
  #
  # @return [User, nil]
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  # @return [Boolean] whether a user is signed in for this request
  def logged_in?
    current_user.present?
  end

  # Before-action helper. Redirects anonymous requests to the login page and
  # remembers the originally-requested URL so sign-in can resume it.
  def require_login
    return if logged_in?

    store_return_to
    redirect_to new_session_path
  end

  # Before-action helper. Allows only users whose role is in the passed list.
  # Anonymous users are sent to login; wrong-role users are sent to the
  # public root with a generic alert.
  def require_role(*roles)
    return require_login unless logged_in?
    return if roles.map(&:to_s).include?(current_user.role)

    redirect_to root_path, alert: t("errors.access_denied", default: "You are not authorised to view that page.")
  end

  # Starts a session for the user, resetting the session ID to mitigate
  # fixation. Used by `SessionsController#create` and by invitation
  # acceptance flows after a password is set.
  #
  # @param user [User]
  # @return [User] the same user, for chaining
  def sign_in_as(user)
    reset_session
    session[:user_id] = user.id
    user
  end

  # Ends the current session entirely.
  # @return [void]
  def sign_out
    reset_session
  end

  private

  def store_return_to
    session[:return_to] = request.fullpath if request.get? || request.head?
  end

  def consume_return_to(default)
    session.delete(:return_to) || default
  end

  def set_locale(&action)
    locale = params[:locale] || cookies[:locale] || I18n.default_locale
    locale = I18n.default_locale unless I18n.available_locales.include?(locale.to_sym)
    cookies[:locale] = { value: locale, expires: 1.year.from_now }
    I18n.with_locale(locale, &action)
  end
end
