# Controller for `/settings/edit` and `/settings#update`. Lets the
# signed-in user edit their own account, password, profile, and locale
# preference. Form behaviour is implemented incrementally; the routing
# shell exists from the start of spec 7 to make the user menu's
# Settings link non-broken.
class SettingsController < ApplicationController
  before_action :require_login

  def edit
  end

  def update
    redirect_to edit_settings_path
  end
end
