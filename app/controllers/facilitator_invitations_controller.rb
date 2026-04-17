# Accept-invitation page for a newly-invited facilitator. The token is the
# sole authorisation for this controller — no session is required (the user
# is activating their account).
class FacilitatorInvitationsController < ApplicationController
  before_action :set_user_from_token

  def edit
  end

  def update
    if @user.update(facilitator_accept_params)
      @user.accept_invitation!
      sign_in_as(@user)
      redirect_to admin_root_path,
                  notice: t("facilitator_invitations.update.notice",
                            default: "Welcome to IMASUS. Your account is ready.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user_from_token
    token = params[:token].to_s
    @user = token.present? ? User.find_by(invitation_token: token) : nil

    if @user.nil? || @user.invitation_expired?
      redirect_to new_session_path,
                  alert: t("facilitator_invitations.token_invalid",
                           default: "That invitation link is invalid or has expired. Please contact the IMASUS administrator.")
    end
  end

  def facilitator_accept_params
    params.require(:user).permit(:name, :password, :password_confirmation)
  end
end
