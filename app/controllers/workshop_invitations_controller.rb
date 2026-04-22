# Facilitator-facing UI for bulk-inviting participants to a given workshop.
# Invitation lives under `/workshops/:workshop_id/invitations` so the
# target workshop is implicit from the URL.
class WorkshopInvitationsController < ApplicationController
  before_action -> { require_role :facilitator, :admin }
  before_action :set_workshop

  def new
  end

  def create
    result = InviteParticipantsToWorkshop.call(workshop: @workshop, emails: params[:emails])

    redirect_to workshop_path(@workshop),
                notice: t("workshop_invitations.create.notice",
                          default: "%{invited} invited, %{skipped} already registered, %{invalid} invalid email(s).",
                          invited: result.invited.size,
                          skipped: result.already_registered.size,
                          invalid: result.invalid.size)
  end

  private

  def set_workshop
    @workshop = Workshop.find_by!(slug: params[:workshop_slug] || params[:workshop_id])
  end
end
