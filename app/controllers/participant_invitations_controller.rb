# Accept-invitation page for a newly-invited participant. The token is the
# sole authorisation. On successful acceptance the participant is signed in
# and redirected to the workshop they were invited to.
class ParticipantInvitationsController < ApplicationController
  before_action :set_user_from_token
  before_action :set_workshop

  def edit
  end

  def update
    if @user.update(participant_accept_params)
      @user.accept_invitation!
      sign_in_as(@user)
      redirect_to target_workshop_path,
                  notice: t("participant_invitations.update.notice",
                            default: "Welcome to IMASUS. You can start exploring the workshop now.")
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
                  alert: t("participant_invitations.token_invalid",
                           default: "That invitation link is invalid or has expired. Please contact your facilitator.")
    end
  end

  def participant_accept_params
    attrs = params.require(:user).permit(:name, :institution, :country, :bio, :links,
                                         :password, :password_confirmation)

    if attrs[:password].present? && attrs[:password_confirmation].blank?
      attrs[:password_confirmation] = attrs[:password]
    end

    attrs
  end

  def target_workshop_path
    @workshop ? workshop_path(@workshop) : root_path
  end

  def set_workshop
    @workshop = @user.workshop_participations.order(:created_at).last&.workshop
  end
end
