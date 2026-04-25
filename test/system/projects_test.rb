require "application_system_test_case"

class ProjectsTest < ApplicationSystemTestCase
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
    @creator  = User.create!(name: "Creator",  email: "creator@example.com",  password: @password, role: :participant)
    @teammate = User.create!(name: "Teammate", email: "teammate@example.com", password: @password, role: :participant)

    WorkshopParticipation.create!(user: @creator,  workshop: @workshop)
    WorkshopParticipation.create!(user: @teammate, workshop: @workshop)
  end

  def sign_in_as(user)
    visit new_session_url
    fill_in "email",    with: user.email
    fill_in "password", with: @password
    click_button I18n.t("sessions.new.submit")
    assert_no_current_path new_session_path, wait: 5
  end

  test "participant creates a project from the workshop show page" do
    sign_in_as(@creator)
    visit workshop_url(@workshop)

    click_link I18n.t("workshops.show.new_project")

    assert_selector "h1", text: I18n.t("projects.new.heading")
    fill_in I18n.t("projects.form.title"), with: "Kapok Fibre Project"
    click_button I18n.t("projects.form.submit_create")

    assert_selector "h1", text: "Kapok Fibre Project"
    assert_selector "[title='#{@creator.name}']"
  end

  test "member can invite another workshop participant from the project show page" do
    sign_in_as(@creator)
    visit workshop_url(@workshop)
    click_link I18n.t("workshops.show.new_project")
    fill_in I18n.t("projects.form.title"), with: "Musa Textile Project"
    click_button I18n.t("projects.form.submit_create")

    click_link I18n.t("projects.show.add_member")
    within("turbo-frame#preview") do
      select @teammate.name, from: I18n.t("project_memberships.form.user_select")
      click_button I18n.t("project_memberships.form.submit")
    end

    assert_selector "[title='#{@teammate.name}']"
  end

  test "facilitator visits a project and sees the facilitator chip but no edit affordances" do
    facilitator = User.create!(name: "Fac", email: "fac@example.com", password: @password, role: :facilitator)
    project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: project, user: @creator)

    sign_in_as(facilitator)
    visit project_url(project)

    assert_selector "[data-role='facilitator-chip']"
    assert_no_selector "a", text: I18n.t("projects.show.edit")
    assert_no_selector "a", text: I18n.t("projects.show.add_member")
  end
end
