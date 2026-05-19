require "test_helper"

class Admin::FacilitatorWorkshopAssignmentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @workshop = Workshop.create!(
      slug: "italy-2026",
      title_translations: { "it" => "Workshop IMASUS Italia" },
      description_translations: { "it" => "Un workshop a Prato." },
      location: "Prato, Italy",
      starts_on: Date.new(2026, 6, 3),
      ends_on: Date.new(2026, 6, 5)
    )
    @admin       = User.create!(name: "Admin",  email: "admin@example.com",  password: @password, role: :admin)
    @facilitator = User.create!(name: "Lauren", email: "lauren@example.com", password: @password, role: :facilitator)
    @participant = User.create!(name: "Part",   email: "part@example.com",   password: @password, role: :participant)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "unauthenticated POST redirects to login" do
    post admin_facilitator_workshop_assignments_path(@facilitator),
         params: { workshop_id: @workshop.id }
    assert_redirected_to new_session_path
    assert_equal 0, WorkshopParticipation.count
  end

  test "facilitator role denied" do
    sign_in(@facilitator)
    assert_no_difference -> { WorkshopParticipation.count } do
      post admin_facilitator_workshop_assignments_path(@facilitator),
           params: { workshop_id: @workshop.id }
    end
    assert_redirected_to root_path
  end

  test "admin assigns a workshop to a facilitator" do
    sign_in(@admin)
    assert_difference -> { WorkshopParticipation.count }, 1 do
      post admin_facilitator_workshop_assignments_path(@facilitator),
           params: { workshop_id: @workshop.id }
    end
    assert_redirected_to admin_facilitator_path(@facilitator)
    assert WorkshopParticipation.exists?(user: @facilitator, workshop: @workshop)
  end

  test "after assignment, facilitator can manage the workshop" do
    sign_in(@admin)
    refute @workshop.reload.manageable_by?(@facilitator)
    post admin_facilitator_workshop_assignments_path(@facilitator),
         params: { workshop_id: @workshop.id }
    assert @workshop.reload.manageable_by?(@facilitator)
  end

  test "assignment is idempotent — second post does not duplicate or raise" do
    sign_in(@admin)
    post admin_facilitator_workshop_assignments_path(@facilitator),
         params: { workshop_id: @workshop.id }
    assert_no_difference -> { WorkshopParticipation.count } do
      post admin_facilitator_workshop_assignments_path(@facilitator),
           params: { workshop_id: @workshop.id }
    end
    assert_redirected_to admin_facilitator_path(@facilitator)
  end

  test "invalid workshop_id redirects back with alert flash" do
    sign_in(@admin)
    assert_no_difference -> { WorkshopParticipation.count } do
      post admin_facilitator_workshop_assignments_path(@facilitator),
           params: { workshop_id: 999_999 }
    end
    assert_redirected_to admin_facilitator_path(@facilitator)
    assert flash[:alert].present?
  end

  test "cannot assign workshops to a non-facilitator user" do
    sign_in(@admin)
    assert_no_difference -> { WorkshopParticipation.count } do
      post admin_facilitator_workshop_assignments_path(@participant),
           params: { workshop_id: @workshop.id }
    end
    assert_response :not_found
  end

  test "unauthenticated DELETE redirects to login" do
    participation = WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    assert_no_difference -> { WorkshopParticipation.count } do
      delete admin_facilitator_workshop_assignment_path(@facilitator, participation)
    end
    assert_redirected_to new_session_path
  end

  test "facilitator role denied from DELETE" do
    participation = WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    sign_in(@facilitator)
    assert_no_difference -> { WorkshopParticipation.count } do
      delete admin_facilitator_workshop_assignment_path(@facilitator, participation)
    end
    assert_redirected_to root_path
  end

  test "admin unassigns a workshop from a facilitator" do
    participation = WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    sign_in(@admin)
    assert_difference -> { WorkshopParticipation.count }, -1 do
      delete admin_facilitator_workshop_assignment_path(@facilitator, participation)
    end
    assert_redirected_to admin_facilitator_path(@facilitator)
  end

  test "after unassignment, facilitator can no longer manage the workshop" do
    participation = WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    assert @workshop.reload.manageable_by?(@facilitator)
    sign_in(@admin)
    delete admin_facilitator_workshop_assignment_path(@facilitator, participation)
    refute @workshop.reload.manageable_by?(@facilitator)
  end

  test "unassignment does not destroy projects in the workshop" do
    WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    project = Project.create!(workshop: @workshop, title: "Some project", language: "it", status: "draft")
    sign_in(@admin)
    assert_no_difference -> { Project.count } do
      participation = WorkshopParticipation.find_by!(user: @facilitator, workshop: @workshop)
      delete admin_facilitator_workshop_assignment_path(@facilitator, participation)
    end
    assert Project.exists?(project.id)
  end

  test "DELETE on a missing participation returns 404" do
    sign_in(@admin)
    delete admin_facilitator_workshop_assignment_path(@facilitator, 999_999)
    assert_response :not_found
  end

  test "delete_confirmation renders the turbo modal for admin" do
    participation = WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    sign_in(@admin)
    get delete_confirmation_admin_facilitator_workshop_assignment_path(@facilitator, participation)
    assert_response :success
    assert_select "turbo-frame#modal"
  end

  test "delete_confirmation form breaks out of the modal frame on submit" do
    participation = WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    sign_in(@admin)
    get delete_confirmation_admin_facilitator_workshop_assignment_path(@facilitator, participation)
    assert_select "turbo-frame#modal form[data-turbo-frame=?]", "_top"
  end

  test "delete_confirmation denied for facilitator role" do
    participation = WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    sign_in(@facilitator)
    get delete_confirmation_admin_facilitator_workshop_assignment_path(@facilitator, participation)
    assert_redirected_to root_path
  end
end
