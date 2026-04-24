require "test_helper"

class LogEntriesControllerTest < ActionDispatch::IntegrationTest
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
    @admin       = User.create!(name: "Admin",       email: "admin@example.com",       password: @password, role: :admin)
    @facilitator = User.create!(name: "Facilitator", email: "fac@example.com",         password: @password, role: :facilitator)
    @member      = User.create!(name: "Member",      email: "member@example.com",      password: @password, role: :participant)
    @other       = User.create!(name: "Other",       email: "other@example.com",       password: @password, role: :participant)

    WorkshopParticipation.create!(user: @member, workshop: @workshop)

    @project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: @project, user: @member)

    @entry = LogEntry.create!(project: @project, author: @member, body: "We tried indigo dyeing.")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  # --- index ---

  test "index redirects unauthenticated user" do
    get project_log_entries_path(@project)
    assert_redirected_to new_session_path
  end

  test "member can view log index" do
    sign_in(@member)
    get project_log_entries_path(@project)
    assert_response :ok
  end

  test "facilitator can view log index" do
    sign_in(@facilitator)
    get project_log_entries_path(@project)
    assert_response :ok
  end

  test "admin can view log index" do
    sign_in(@admin)
    get project_log_entries_path(@project)
    assert_response :ok
  end

  test "non-member participant is redirected from log index" do
    sign_in(@other)
    get project_log_entries_path(@project)
    assert_redirected_to root_path
  end

  # --- new ---

  test "new redirects unauthenticated user" do
    get new_project_log_entry_path(@project)
    assert_redirected_to new_session_path
  end

  test "member can view new entry form" do
    sign_in(@member)
    get new_project_log_entry_path(@project)
    assert_response :ok
  end

  test "facilitator cannot view new entry form" do
    sign_in(@facilitator)
    get new_project_log_entry_path(@project)
    assert_redirected_to root_path
  end

  # --- create ---

  test "create redirects unauthenticated user" do
    post project_log_entries_path(@project), params: { log_entry: { body: "New entry" } }
    assert_redirected_to new_session_path
  end

  test "member can create an entry" do
    sign_in(@member)
    assert_difference "LogEntry.count", 1 do
      post project_log_entries_path(@project), params: { log_entry: { body: "We tried weaving." } }
    end
    assert_redirected_to project_log_entries_path(@project)
  end

  test "create sets author to current user" do
    sign_in(@member)
    post project_log_entries_path(@project), params: { log_entry: { body: "Author check." } }
    assert_equal @member, LogEntry.last.author
  end

  test "facilitator cannot create an entry" do
    sign_in(@facilitator)
    assert_no_difference "LogEntry.count" do
      post project_log_entries_path(@project), params: { log_entry: { body: "Should not save." } }
    end
    assert_redirected_to root_path
  end

  test "create with blank body re-renders new" do
    sign_in(@member)
    assert_no_difference "LogEntry.count" do
      post project_log_entries_path(@project), params: { log_entry: { body: "" } }
    end
    assert_response :unprocessable_entity
  end

  # --- destroy ---

  test "destroy redirects unauthenticated user" do
    delete project_log_entry_path(@project, @entry)
    assert_redirected_to new_session_path
  end

  test "author can delete their own entry" do
    sign_in(@member)
    assert_difference "LogEntry.count", -1 do
      delete project_log_entry_path(@project, @entry)
    end
    assert_redirected_to project_log_entries_path(@project)
  end

  test "admin can delete any entry" do
    sign_in(@admin)
    assert_difference "LogEntry.count", -1 do
      delete project_log_entry_path(@project, @entry)
    end
  end

  test "other member cannot delete another member's entry" do
    other_member = User.create!(name: "Other Member", email: "otherm@example.com", password: @password, role: :participant)
    WorkshopParticipation.create!(user: other_member, workshop: @workshop)
    ProjectMembership.create!(project: @project, user: other_member)

    sign_in(other_member)
    assert_no_difference "LogEntry.count" do
      delete project_log_entry_path(@project, @entry)
    end
    assert_redirected_to project_log_entries_path(@project)
  end
end
