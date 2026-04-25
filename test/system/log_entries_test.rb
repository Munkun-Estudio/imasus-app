require "application_system_test_case"

class LogEntriesTest < ApplicationSystemTestCase
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
    @member      = User.create!(name: "Member", email: "member@example.com", password: @password, role: :participant)
    @facilitator = User.create!(name: "Fac",    email: "fac@example.com",    password: @password, role: :facilitator)

    WorkshopParticipation.create!(user: @member, workshop: @workshop)

    @project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: @project, user: @member)
  end

  def teardown
    LogEntry.destroy_all
    super
  end

  def sign_in_as(user)
    visit new_session_url
    fill_in "email",    with: user.email
    fill_in "password", with: @password
    click_button I18n.t("sessions.new.submit")
    assert_no_current_path new_session_path, wait: 5
  end

  test "member opens process log from project show page" do
    sign_in_as(@member)
    visit project_url(@project)

    click_link I18n.t("projects.show.process_log_cta")

    assert_current_path project_log_entries_path(@project)
  end

  test "member creates a log entry and sees it at the top" do
    sign_in_as(@member)
    visit project_log_entries_url(@project)

    first("a", text: I18n.t("log_entries.index.new_entry")).click
    find("trix-editor", wait: 5)
    execute_script(<<~JS)
      var input = document.querySelector('input[id$="trix_input_log_entry"]');
      input.value = '<p>We tested natural indigo dyeing on wool.</p>';
    JS
    click_button I18n.t("log_entries.form.submit")

    assert_current_path project_log_entries_path(@project)
    assert_selector "[data-role='log-entry']", text: "We tested natural indigo dyeing on wool."
    assert_selector "[data-role='log-entry'] [data-role='author-name']", text: @member.name
  end

  test "facilitator sees log entries but no add-entry affordance" do
    LogEntry.create!(project: @project, author: @member, body: "Existing entry from member.")

    sign_in_as(@facilitator)
    visit project_log_entries_url(@project)

    assert_selector "[data-role='log-entry']", text: "Existing entry from member."
    assert_no_selector "a", text: I18n.t("log_entries.index.new_entry")
  end

  test "member can delete their own entry" do
    entry = LogEntry.create!(project: @project, author: @member, body: "Entry to delete.")

    sign_in_as(@member)
    visit project_log_entries_url(@project)

    assert_selector "[data-role='log-entry']"
    within "[data-role='log-entry'][data-entry-id='#{entry.id}']" do
      click_link I18n.t("log_entries.entry.delete")
    end

    # Modal appears — confirm deletion
    assert_selector "turbo-frame#modal [role='dialog']"
    click_button I18n.t("log_entries.confirm_delete.confirm")

    assert_no_selector "[data-role='log-entry'][data-entry-id='#{entry.id}']"
  end
end
