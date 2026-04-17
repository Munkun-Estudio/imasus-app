class Admin::FacilitatorsController < ApplicationController
  before_action -> { require_role :admin }

  def index
    @facilitators = User.facilitator.order(:name)
  end

  def new
    @user = User.new(role: :facilitator)
  end

  def create
    @user = User.new(
      facilitator_params.merge(
        role: :facilitator,
        invitation_token: SecureRandom.urlsafe_base64(32),
        invitation_sent_at: Time.current
      )
    )

    if @user.save
      FacilitatorInvitationMailer.invite(@user, @user.invitation_token).deliver_later
      redirect_to admin_facilitators_path,
                  notice: t("admin.facilitators.create.notice",
                            default: "Facilitator invited. They will receive an email with a link to set their password.")
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def facilitator_params
    params.require(:user).permit(:name, :email)
  end
end
