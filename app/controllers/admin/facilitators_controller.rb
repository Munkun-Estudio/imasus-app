# Admin surface for managing facilitator accounts. Lists facilitators,
# invites new ones (optionally pre-assigned to workshops), shows a
# per-facilitator page with their workshop assignments, and revokes
# pending invitations. Workshop assignments themselves live on
# {Admin::FacilitatorWorkshopAssignmentsController}.
class Admin::FacilitatorsController < ApplicationController
  before_action -> { require_role :admin }
  before_action :set_facilitator, only: [ :show, :destroy, :revoke_confirmation ]

  def index
    @facilitators = User.facilitator.order(:name)
  end

  # Renders the per-facilitator admin page: assigned workshops with
  # an Unassign affordance, an "Assign workshop" form populated with
  # workshops the facilitator is not yet on, and (for pending
  # invitations) a Revoke invitation section.
  def show
    @assigned_workshops = @facilitator.workshops.order(:starts_on)
    @assignable_workshops = Workshop.where.not(id: @assigned_workshops.select(:id)).order(:starts_on)
  end

  # Turbo-modal confirmation for revoking a pending invitation.
  # Refuses if the facilitator has already accepted the invitation,
  # because hard-deleting an active facilitator account is out of
  # scope for this spec (their content cascades and that needs its
  # own design pass).
  def revoke_confirmation
    unless pending?(@facilitator)
      redirect_to admin_facilitator_path(@facilitator),
                  alert: t("admin.facilitators.revoke.refused",
                           default: "This facilitator has already accepted their invitation. Revoke is only available for pending invitations.")
      return
    end
    render partial: "admin/facilitators/confirm_revoke_modal",
           locals: { facilitator: @facilitator }
  end

  # Hard-deletes the facilitator user when their invitation has not
  # yet been accepted. Cascades through
  # {User#workshop_participations} via `dependent: :destroy`, so any
  # pre-assigned (but never used) workshop links are removed too.
  # Accepted facilitators are refused at this surface.
  def destroy
    unless pending?(@facilitator)
      redirect_to admin_facilitator_path(@facilitator),
                  alert: t("admin.facilitators.revoke.refused",
                           default: "This facilitator has already accepted their invitation. Revoke is only available for pending invitations.")
      return
    end

    name = @facilitator.name
    @facilitator.destroy
    redirect_to admin_facilitators_path,
                notice: t("admin.facilitators.revoke.notice",
                          default: "Invitation for %{name} has been revoked.",
                          name: name)
  end

  def new
    @user = User.new(role: :facilitator)
  end

  # Creates a new facilitator user, sends the invitation email, and
  # optionally pre-assigns workshops in the same transaction. If any
  # `workshop_ids` entry is invalid (or the user save fails), the
  # whole transaction rolls back and the form re-renders with errors.
  # The mailer is only triggered after a successful commit.
  def create
    @user = User.new(
      facilitator_params.merge(
        role: :facilitator,
        invitation_token: SecureRandom.urlsafe_base64(32),
        invitation_sent_at: Time.current
      )
    )
    workshop_ids = Array(params[:workshop_ids]).reject(&:blank?)

    saved =
      begin
        ActiveRecord::Base.transaction do
          @user.save!
          workshop_ids.each do |id|
            workshop = Workshop.find(id)
            WorkshopParticipation.create!(user: @user, workshop: workshop)
          end
        end
        true
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
        false
      end

    if saved
      FacilitatorInvitationMailer.invite(@user, @user.invitation_token).deliver_later
      redirect_to admin_facilitators_path,
                  notice: t("admin.facilitators.create.notice",
                            default: "Facilitator invited. They will receive an email with a link to set their password.")
    else
      @user.errors.add(:base, t("admin.facilitators.create.invalid_workshop", default: "One of the selected workshops could not be found.")) if workshop_ids.any? && @user.errors.empty?
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_facilitator
    @facilitator = User.facilitator.find(params[:id])
  end

  def pending?(user)
    user.invitation_accepted_at.nil?
  end

  def facilitator_params
    params.require(:user).permit(:name, :email)
  end
end
