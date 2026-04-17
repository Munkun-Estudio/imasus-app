# Password reset by email token. Uses a single generic confirmation copy
# regardless of whether the email is known, to prevent enumeration.
class PasswordResetsController < ApplicationController
  before_action :set_user_from_token, only: [ :edit, :update ]

  def new
  end

  def create
    email = params[:email].to_s.strip.downcase
    user  = User.find_by("LOWER(email) = ?", email)

    if user
      user.generate_password_reset_token!
      PasswordResetMailer.reset(user, user.password_reset_token).deliver_later
    end

    redirect_to new_session_path,
                notice: t("password_resets.create.notice",
                          default: "If that email matches an account, we have sent a reset link.")
  end

  def edit
  end

  def update
    if @user.update(password_params)
      @user.clear_password_reset!
      # Invalidate any other active sessions on this account before issuing
      # a fresh one for the owner who just reset the password.
      reset_session
      redirect_to new_session_path,
                  notice: t("password_resets.update.notice",
                            default: "Password updated. You can sign in now.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user_from_token
    token = params[:token].to_s
    @user = token.present? ? User.find_by(password_reset_token: token) : nil

    if @user.nil? || @user.password_reset_expired?
      redirect_to new_password_reset_path,
                  alert: t("password_resets.token_invalid",
                           default: "That reset link is invalid or has expired.")
    end
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
