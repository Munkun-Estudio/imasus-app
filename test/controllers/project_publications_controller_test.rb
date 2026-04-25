require "test_helper"

class ProjectPublicationsControllerTest < ActionDispatch::IntegrationTest
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

    WorkshopParticipation.create!(user: @member,   workshop: @workshop)
    WorkshopParticipation.create!(user: @outsider, workshop: @workshop)

    @project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: @project, user: @member)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  def hero_upload
    fixture_file_upload("sample-image.png", "image/png")
  end

  def publish_project!(project)
    project.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
    project.process_summary = "<p>Existing summary</p>"
    project.status = "published"
    project.publication_updated_at = Time.current
    project.save!
  end

  # --- new ---

  test "new requires login" do
    get new_project_publication_url(@project)
    assert_redirected_to new_session_path
  end

  test "new renders for member on draft project" do
    sign_in(@member)
    get new_project_publication_url(@project)
    assert_response :success
  end

  test "new shows process log entries for reuse" do
    LogEntry.create!(project: @project, author: @member, body: "We tested indigo on wool.")

    sign_in(@member)
    get new_project_publication_url(@project)

    assert_response :success
    assert_select "[data-publication-wizard-target='logEntry'][data-section='process']"
    assert_select "[data-publication-wizard-target='logEntry'][data-section='insights']"
    assert_select "[data-publication-wizard-target='logEntry'][data-section='outcome']"
    assert_includes response.body, "We tested indigo on wool."
  end

  test "new renders for admin on draft project" do
    sign_in(@admin)
    get new_project_publication_url(@project)
    assert_response :success
  end

  test "new redirects member if project is already published" do
    publish_project!(@project)
    sign_in(@member)
    get new_project_publication_url(@project)
    assert_redirected_to project_path(@project)
  end

  test "new forbidden for facilitator" do
    sign_in(@facilitator)
    get new_project_publication_url(@project)
    assert_redirected_to project_path(@project)
    assert_not_nil flash[:alert]
  end

  test "new forbidden for non-member participant" do
    sign_in(@outsider)
    get new_project_publication_url(@project)
    assert_redirected_to project_path(@project)
    assert_not_nil flash[:alert]
  end

  # --- create ---

  test "create publishes the project and redirects to public page" do
    sign_in(@member)
    post project_publication_url(@project), params: {
      project: {
        hero_image: hero_upload,
        process_summary: "<p>How we got here</p>"
      }
    }
    @project.reload
    assert @project.published?
    assert_not_nil @project.slug
    assert_not_nil @project.publication_updated_at
    assert_redirected_to published_project_path(slug: @project.slug)
  end

  test "create allows admin to publish any project" do
    sign_in(@admin)
    post project_publication_url(@project), params: {
      project: {
        hero_image: hero_upload,
        process_summary: "<p>Admin-published summary</p>"
      }
    }
    assert @project.reload.published?
    assert_redirected_to published_project_path(slug: @project.slug)
  end

  test "create re-renders new on missing hero_image" do
    sign_in(@member)
    post project_publication_url(@project), params: {
      project: { process_summary: "<p>No hero</p>" }
    }
    assert_response :unprocessable_entity
    assert_equal "draft", @project.reload.status
  end

  test "create re-renders new on missing process_summary" do
    sign_in(@member)
    post project_publication_url(@project), params: {
      project: { hero_image: hero_upload, process_summary: "" }
    }
    assert_response :unprocessable_entity
    assert_equal "draft", @project.reload.status
  end

  test "create forbidden for facilitator" do
    sign_in(@facilitator)
    post project_publication_url(@project), params: {
      project: { hero_image: hero_upload, process_summary: "<p>hi</p>" }
    }
    assert_redirected_to project_path(@project)
    assert_equal "draft", @project.reload.status
  end

  # --- edit ---

  test "edit requires login" do
    get edit_project_publication_url(@project)
    assert_redirected_to new_session_path
  end

  test "edit renders for member on published project" do
    publish_project!(@project)
    sign_in(@member)
    get edit_project_publication_url(@project)
    assert_response :success
  end

  test "edit redirects if project is still draft" do
    sign_in(@member)
    get edit_project_publication_url(@project)
    assert_redirected_to project_path(@project)
  end

  test "edit forbidden for facilitator on published project" do
    publish_project!(@project)
    sign_in(@facilitator)
    get edit_project_publication_url(@project)
    assert_redirected_to project_path(@project)
  end

  # --- update ---

  test "update saves fields and refreshes publication_updated_at without changing slug" do
    publish_project!(@project)
    original_slug = @project.slug
    original_ts   = @project.publication_updated_at
    sign_in(@member)

    travel_to 1.hour.from_now do
      patch project_publication_url(@project), params: {
        project: { process_summary: "<p>Revised summary</p>" }
      }
    end

    @project.reload
    assert_equal original_slug, @project.slug
    assert @project.publication_updated_at > original_ts
    assert_equal "Revised summary", @project.process_summary.to_plain_text.strip
    assert_redirected_to published_project_path(slug: @project.slug)
  end

  test "update forbidden for facilitator" do
    publish_project!(@project)
    sign_in(@facilitator)
    patch project_publication_url(@project), params: {
      project: { process_summary: "<p>Hacked</p>" }
    }
    assert_redirected_to project_path(@project)
  end
end
