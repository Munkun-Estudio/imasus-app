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
  # given workshop. The Rails-level uniqueness validation on
  # WorkshopParticipation makes `find_or_create_by!` idempotent for
  # sequential submits; the rescue below handles the race where two
  # concurrent POSTs both pass the SELECT and the DB unique index on
  # `(user_id, workshop_id)` rejects one of the INSERTs. Invalid
  # `workshop_id` redirects back with an alert instead of raising.
  def create
    workshop = Workshop.find_by(id: params[:workshop_id])
    if workshop.nil?
      redirect_to admin_facilitator_path(@facilitator),
                  alert: t("admin.facilitator_workshop_assignments.create.invalid_workshop",
                           default: "That workshop could not be found.")
      return
    end

    begin
      WorkshopParticipation.find_or_create_by!(user: @facilitator, workshop: workshop)
    rescue ActiveRecord::RecordNotUnique
      # Concurrent submit beat us to the INSERT; the row exists either way.
    end

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
