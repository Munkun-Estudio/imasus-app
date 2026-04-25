require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @workshop = Workshop.create!(
      slug: "spain-2026",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      partner: "Munkun",
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @admin       = User.create!(name: "Admin",     email: "admin@example.com",     password: @password, role: :admin)
    @facilitator = User.create!(name: "Fac",       email: "fac@example.com",       password: @password, role: :facilitator)
    @member      = User.create!(name: "Member",    email: "member@example.com",    password: @password, role: :participant)
    @outsider    = User.create!(name: "Outsider",  email: "outsider@example.com",  password: @password, role: :participant)
    @other       = User.create!(name: "Other",     email: "other@example.com",     password: @password, role: :participant)

    WorkshopParticipation.create!(user: @member,   workshop: @workshop)
    WorkshopParticipation.create!(user: @other,    workshop: @workshop)

    @project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: @project, user: @member)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  # --- index ---

  test "index requires login" do
    get projects_url
    assert_redirected_to new_session_path
  end

  test "participant is redirected from index to their workshops with a notice" do
    sign_in(@member)
    get projects_url
    assert_redirected_to workshops_path
    assert_equal I18n.t("projects.index.participant_redirect"), flash[:notice]
  end

  test "participant without projects is also redirected" do
    sign_in(@outsider)
    get projects_url
    assert_redirected_to workshops_path
  end

  test "admin sees all projects" do
    sign_in(@admin)
    get projects_url
    assert_response :success
    assert_select "[data-project-id='#{@project.id}']"
  end

  test "facilitator sees all projects" do
    sign_in(@facilitator)
    get projects_url
    assert_response :success
    assert_select "[data-project-id='#{@project.id}']"
  end

  # --- new ---

  test "new requires login" do
    get new_project_url(workshop_id: @workshop.id)
    assert_redirected_to new_session_path
  end

  test "new redirects non-participant with flash" do
    sign_in(@outsider)
    get new_project_url(workshop_id: @workshop.id)
    assert_redirected_to workshop_path(@workshop)
    assert_not_nil flash[:alert]
  end

  test "new renders form for workshop participant" do
    sign_in(@member)
    get new_project_url(workshop_id: @workshop.id)
    assert_response :success
  end

  test "new without workshop_id redirects" do
    sign_in(@member)
    get new_project_url
    assert_redirected_to workshops_path
  end

  # --- create ---

  test "create requires login" do
    post projects_url, params: { project: { workshop_id: @workshop.id, title: "Test", language: "es" } }
    assert_redirected_to new_session_path
  end

  test "create succeeds and creates project plus creator membership atomically" do
    sign_in(@member)
    assert_difference [ "Project.count", "ProjectMembership.count" ], 1 do
      post projects_url, params: { project: { workshop_id: @workshop.id, title: "New Project", language: "es" } }
    end
    project = Project.order(created_at: :desc).first
    assert_redirected_to project_path(project)
    assert ProjectMembership.exists?(project: project, user: @member)
  end

  test "create re-renders new on validation failure" do
    sign_in(@member)
    assert_no_difference "Project.count" do
      post projects_url, params: { project: { workshop_id: @workshop.id, title: "", language: "es" } }
    end
    assert_response :unprocessable_entity
  end

  test "create for non-workshop-participant is blocked" do
    sign_in(@outsider)
    assert_no_difference "Project.count" do
      post projects_url, params: { project: { workshop_id: @workshop.id, title: "Blocked", language: "es" } }
    end
    assert_redirected_to workshop_path(@workshop)
  end

  # --- show ---

  test "show requires login" do
    get project_url(@project)
    assert_redirected_to new_session_path
  end

  test "show returns 200 for a member" do
    sign_in(@member)
    get project_url(@project)
    assert_response :success
  end

  test "show add member link targets the preview drawer frame" do
    sign_in(@member)
    get project_url(@project)
    assert_response :success
    assert_select "a[href=?][data-turbo-frame='preview']", new_project_membership_path(@project),
                  text: I18n.t("projects.show.add_member")
  end

  test "show returns 200 for a facilitator with a facilitator chip" do
    sign_in(@facilitator)
    get project_url(@project)
    assert_response :success
    assert_select "[data-role='facilitator-chip']"
  end

  test "show returns 200 for an admin" do
    sign_in(@admin)
    get project_url(@project)
    assert_response :success
  end

  test "show redirects a non-member participant to their workshops" do
    sign_in(@outsider)
    get project_url(@project)
    assert_redirected_to workshops_path
    assert_not_nil flash[:alert]
  end

  # --- edit / update ---

  test "edit requires login" do
    get edit_project_url(@project)
    assert_redirected_to new_session_path
  end

  test "edit renders for a member" do
    sign_in(@member)
    get edit_project_url(@project)
    assert_response :success
  end

  test "edit is forbidden for a facilitator" do
    sign_in(@facilitator)
    get edit_project_url(@project)
    assert_redirected_to project_path(@project)
  end

  test "update succeeds for a member" do
    sign_in(@member)
    patch project_url(@project), params: { project: { title: "Updated Title" } }
    assert_redirected_to project_path(@project)
    assert_equal "Updated Title", @project.reload.title
  end

  test "update re-renders edit on validation failure" do
    sign_in(@member)
    patch project_url(@project), params: { project: { title: "" } }
    assert_response :unprocessable_entity
  end

  test "update is forbidden for a facilitator" do
    sign_in(@facilitator)
    patch project_url(@project), params: { project: { title: "Hacked" } }
    assert_redirected_to project_path(@project)
    assert_not_equal "Hacked", @project.reload.title
  end

  # --- destroy ---

  test "destroy requires login" do
    delete project_url(@project)
    assert_redirected_to new_session_path
  end

  test "member can destroy their project" do
    sign_in(@member)
    assert_difference "Project.count", -1 do
      delete project_url(@project)
    end
    assert_redirected_to projects_path
  end

  test "admin can destroy any project" do
    sign_in(@admin)
    assert_difference "Project.count", -1 do
      delete project_url(@project)
    end
    assert_redirected_to projects_path
  end

  test "facilitator cannot destroy a project" do
    sign_in(@facilitator)
    assert_no_difference "Project.count" do
      delete project_url(@project)
    end
    assert_redirected_to project_path(@project)
  end

  test "non-member participant cannot destroy a project" do
    sign_in(@outsider)
    assert_no_difference "Project.count" do
      delete project_url(@project)
    end
  end

  # --- moderation (spec 13) ---

  test "PATCH disable soft-disables the project for an admin" do
    sign_in(@admin)
    freeze_time do
      patch disable_project_url(@project)
      @project.reload
      assert @project.disabled?
      assert_equal Time.current, @project.disabled_at
      assert_equal @admin, @project.disabled_by
    end
    assert_redirected_to project_path(@project)
  end

  test "PATCH disable allowed for a facilitator who manages the workshop" do
    WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    sign_in(@facilitator)
    patch disable_project_url(@project)
    assert @project.reload.disabled?
  end

  test "PATCH disable forbidden for a facilitator who does not manage the workshop" do
    sign_in(@facilitator)
    patch disable_project_url(@project)
    assert_redirected_to root_path
    assert_not @project.reload.disabled?
  end

  test "PATCH disable forbidden for participants" do
    sign_in(@member)
    patch disable_project_url(@project)
    assert_redirected_to root_path
    assert_not @project.reload.disabled?
  end

  test "PATCH enable clears the disabled state" do
    @project.disable!(by: @admin)
    sign_in(@admin)
    patch enable_project_url(@project)
    assert_not @project.reload.disabled?
  end

  test "show page renders the disabled banner when the project is disabled" do
    @project.disable!(by: @admin)
    sign_in(@member)
    get project_url(@project)
    assert_response :success
    assert_select "[data-disabled-banner]"
  end

  test "show page hides edit and publish CTAs when disabled" do
    @project.disable!(by: @admin)
    sign_in(@member)
    get project_url(@project)
    assert_response :success
    assert_select "a[href=?]", edit_project_path(@project), count: 0
    assert_select "a[href=?]", new_project_publication_path(@project), count: 0
  end

  test "show page exposes the Disable button for managers when active" do
    sign_in(@admin)
    get project_url(@project)
    assert_select "form[action=?]", disable_project_path(@project)
  end

  test "show page exposes the Enable button for managers when disabled" do
    @project.disable!(by: @admin)
    sign_in(@admin)
    get project_url(@project)
    assert_select "form[action=?]", enable_project_path(@project)
  end
end
