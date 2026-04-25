require "test_helper"

class ProjectMembershipsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @workshop = Workshop.create!(
      slug: "spain-2026",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @admin      = User.create!(name: "Admin",   email: "admin@example.com",   password: @password, role: :admin)
    @member     = User.create!(name: "Member",  email: "member@example.com",  password: @password, role: :participant)
    @invitee    = User.create!(name: "Invitee", email: "invitee@example.com", password: @password, role: :participant)
    @outsider   = User.create!(name: "Out",     email: "out@example.com",     password: @password, role: :participant)

    WorkshopParticipation.create!(user: @member,  workshop: @workshop)
    WorkshopParticipation.create!(user: @invitee, workshop: @workshop)

    @project    = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    @membership = ProjectMembership.create!(project: @project, user: @member)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  # --- create ---

  test "create requires login" do
    post project_memberships_url(@project), params: { project_membership: { user_id: @invitee.id } }
    assert_redirected_to new_session_path
  end

  test "member can add a workshop participant" do
    sign_in(@member)
    assert_difference "ProjectMembership.count", 1 do
      post project_memberships_url(@project), params: { project_membership: { user_id: @invitee.id } }
    end
    assert_redirected_to project_path(@project)
  end

  test "create rejects a user who is not a workshop participant" do
    sign_in(@member)
    assert_no_difference "ProjectMembership.count" do
      post project_memberships_url(@project), params: { project_membership: { user_id: @outsider.id } }
    end
    assert_response :unprocessable_entity
  end

  test "create rejects a user already in the project" do
    sign_in(@member)
    assert_no_difference "ProjectMembership.count" do
      post project_memberships_url(@project), params: { project_membership: { user_id: @member.id } }
    end
    assert_response :unprocessable_entity
  end

  test "facilitator cannot add members" do
    facilitator = User.create!(name: "Fac", email: "fac@example.com", password: @password, role: :facilitator)
    sign_in(facilitator)
    assert_no_difference "ProjectMembership.count" do
      post project_memberships_url(@project), params: { project_membership: { user_id: @invitee.id } }
    end
  end

  # --- destroy ---

  test "destroy requires login" do
    delete project_membership_url(@project, @membership)
    assert_redirected_to new_session_path
  end

  test "member can leave the project (remove themselves)" do
    ProjectMembership.create!(project: @project, user: @invitee)
    sign_in(@member)
    assert_difference "ProjectMembership.count", -1 do
      delete project_membership_url(@project, @membership)
    end
    assert_redirected_to projects_path
  end

  test "member cannot remove another member" do
    other_membership = ProjectMembership.create!(project: @project, user: @invitee)
    sign_in(@member)
    assert_no_difference "ProjectMembership.count" do
      delete project_membership_url(@project, other_membership)
    end
    assert_redirected_to project_path(@project)
  end

  test "admin can remove any member" do
    sign_in(@admin)
    assert_difference "ProjectMembership.count", -1 do
      delete project_membership_url(@project, @membership)
    end
  end

  test "leaving as last member destroys the project" do
    project_id = @project.id
    sign_in(@member)
    delete project_membership_url(@project, @membership)
    assert_nil Project.find_by(id: project_id)
    assert_redirected_to projects_path
    assert_not_nil flash[:notice]
  end
end
