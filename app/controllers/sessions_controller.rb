# Cookie-session login / logout. Uses a generic failure message regardless of
# whether the email exists, to prevent user enumeration.
class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by("LOWER(email) = ?", params[:email].to_s.strip.downcase)

    authenticated = if user&.password_digest.present?
      user.authenticate(params[:password])
    else
      # Constant-ish-time dummy compare so the response time for unknown or
      # unactivated accounts matches a real password check (mitigates
      # account-existence enumeration via timing).
      BCrypt::Password.create("dummy").is_password?(params[:password].to_s)
      false
    end

    if authenticated
      return_to = session[:return_to]
      sign_in_as(user)
      redirect_to(return_to || root_path)
    else
      flash.now[:alert] = t("sessions.create.invalid", default: "Invalid email or password.")
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    sign_out
    redirect_to new_session_path,
                notice: t("sessions.destroy.notice", default: "You are now logged out.")
  end
end
