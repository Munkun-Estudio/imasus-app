# Admin-only CRUD on the {WorkshopParticipation} join used as the
# facilitator-access primitive. Lives nested under
# {Admin::FacilitatorsController} so the URLs read as
# `/admin/facilitators/:facilitator_id/workshop_assignments/:id`.
# Assignment is idempotent; unassignment leaves the facilitator's
# existing content (projects, log entries) untouched and only
# revokes their workshop-management access.
class Admin::FacilitatorWorkshopAssignmentsController < ApplicationController
  before_action -> { require_role :admin }
  before_action :set_facilitator
  before_action :set_participation, only: [ :destroy, :delete_confirmation ]

  # Creates a {WorkshopParticipation} linking the facilitator to the
  # given workshop. Idempotent via `find_or_create_by!`. Invalid
  # `workshop_id` redirects back with an alert instead of raising.
  def create
    workshop = Workshop.find_by(id: params[:workshop_id])
    if workshop.nil?
      redirect_to admin_facilitator_path(@facilitator),
                  alert: t("admin.facilitator_workshop_assignments.create.invalid_workshop",
                           default: "That workshop could not be found.")
      return
    end

    WorkshopParticipation.find_or_create_by!(user: @facilitator, workshop: workshop)
    redirect_to admin_facilitator_path(@facilitator),
                notice: t("admin.facilitator_workshop_assignments.create.notice",
                          default: "%{name} can now manage %{workshop}.",
                          name: @facilitator.name,
                          workshop: workshop.title)
  end

  # Renders the Turbo-modal confirmation partial before the actual
  # `DELETE`. Reuses the layout-level `<turbo-frame id="modal">`
  # slot and `modal_controller.js` per the project's confirmation
  # convention.
  def delete_confirmation
    render partial: "admin/facilitator_workshop_assignments/confirm_delete_modal",
           locals: { facilitator: @facilitator, participation: @participation }
  end

  # Destroys the {WorkshopParticipation}. The facilitator immediately
  # loses {Workshop#manageable_by?} on this workshop. Projects, log
  # entries, and other authored content stay intact.
  def destroy
    workshop_title = @participation.workshop.title
    @participation.destroy
    redirect_to admin_facilitator_path(@facilitator),
                notice: t("admin.facilitator_workshop_assignments.destroy.notice",
                          default: "%{name} no longer manages %{workshop}.",
                          name: @facilitator.name,
                          workshop: workshop_title)
  end

  private

  def set_facilitator
    @facilitator = User.facilitator.find(params[:facilitator_id])
  end

  def set_participation
    @participation = WorkshopParticipation.find_by!(id: params[:id], user: @facilitator)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
