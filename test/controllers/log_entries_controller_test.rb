require "test_helper"

class LogEntriesControllerTest < ActionDispatch::IntegrationTest
  LOG_ENTRY_BATCH_SIZE = 10

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

  test "index renders only the first batch of a long timeline" do
    12.times do |index|
      LogEntry.create!(
        project: @project,
        author: @member,
        body: "Batch entry #{index}",
        created_at: index.minutes.ago
      )
    end

    sign_in(@member)
    get project_log_entries_path(@project)

    assert_response :ok
    assert_select "[data-role='log-entry']", count: LOG_ENTRY_BATCH_SIZE
    assert_select "turbo-frame[data-role='log-entries-next-page'][src*='page=2']"
  end

  test "index second page returns the next Turbo-frame batch" do
    entries = 12.times.map do |index|
      LogEntry.create!(
        project: @project,
        author: @member,
        body: "Paged entry #{index}",
        created_at: index.minutes.ago
      )
    end

    sign_in(@member)
    get project_log_entries_path(@project, page: 2),
        headers: { "Turbo-Frame" => "log_entries_page_2" }

    assert_response :ok
    assert_select "turbo-frame#log_entries_page_2"
    expected = @project.log_entries.offset(LOG_ENTRY_BATCH_SIZE).limit(LOG_ENTRY_BATCH_SIZE).pluck(:id)
    expected.each do |entry_id|
      assert_select %([data-role="log-entry"][data-entry-id="#{entry_id}"])
    end
  end

  test "image attachments render as variants rather than original blob URLs" do
    @entry.media.attach(
      io: file_fixture("sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )

    sign_in(@member)
    get project_log_entries_path(@project)

    assert_response :ok
    assert_select "img[data-role='log-entry-image']"
    assert_match %r{/rails/active_storage/representations/}, response.body
  end

  test "video attachments render poster-first without exposing source URLs" do
    @entry.media.attach(
      io: file_fixture("sample-image.png").open,
      filename: "process-video.mp4",
      content_type: "video/mp4",
      identify: false
    )

    sign_in(@member)
    get project_log_entries_path(@project)

    assert_response :ok
    assert_select %([data-role="log-entry-video"][data-media-url=?]),
                  media_project_log_entry_path(@project, @entry, attachment_id: @entry.media.attachments.last.id)
    assert_select "video", count: 0
    refute_includes response.body, "process-video.mp4"
  end

  test "media endpoint renders a video player after user intent" do
    @entry.media.attach(
      io: file_fixture("sample-image.png").open,
      filename: "process-video.mp4",
      content_type: "video/mp4",
      identify: false
    )

    sign_in(@member)
    get media_project_log_entry_path(@project, @entry, attachment_id: @entry.media.attachments.last.id)

    assert_response :ok
    assert_select "video[preload='none'] source"
    assert_includes response.body, "process-video.mp4"
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

  test "admin cannot create an entry without being a project member" do
    sign_in(@admin)
    assert_no_difference "LogEntry.count" do
      post project_log_entries_path(@project), params: { log_entry: { body: "Admin entry." } }
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
