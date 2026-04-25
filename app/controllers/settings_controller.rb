# Account-self-service controller. Lets the signed-in user edit their
# own account, password, profile, and locale preference. The form is a
# single page with four labelled sections (Account / Password /
# Profile / Preferences). Empty password fields leave the password
# unchanged; rotating the password requires `current_password` to
# match.
class SettingsController < ApplicationController
  before_action :require_login

  # @note Renders the four-section form (Account / Password / Profile /
  #   Preferences). Pre-populates fields from the signed-in user.
  def edit
    @user = current_user
  end

  # @note Empty password fields skip the rotation challenge entirely; a
  #   new password requires +current_password+ to authenticate. An empty
  #   +preferred_locale+ is normalised to nil so the inclusion validation
  #   accepts "System default".
  def update
    @user = current_user

    return render :edit, status: :unprocessable_content unless authorise_password_change

    if @user.update(attributes_for_update)
      redirect_to edit_settings_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  # Validates that the password rotation is allowed before any save:
  # blank password fields are always fine (no rotation requested);
  # otherwise `current_password` must authenticate.
  def authorise_password_change
    return true if blank_password?
    return true if @user.authenticate(params.dig(:user, :current_password).to_s)

    @user.errors.add(:current_password, :invalid)
    false
  end

  def blank_password?
    params.dig(:user, :password).blank? &&
      params.dig(:user, :password_confirmation).blank?
  end

  def attributes_for_update
    attrs = settings_params.except(:current_password)
    attrs = attrs.except(:password, :password_confirmation) if blank_password?
    attrs[:preferred_locale] = nil if attrs[:preferred_locale].blank?
    attrs
  end

  def settings_params
    params.require(:user).permit(
      :name, :email,
      :current_password, :password, :password_confirmation,
      :institution, :country, :bio, :links,
      :preferred_locale
    )
  end
end
