require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
  end

  def make_workshop(slug: "spain-2026", contact_email: nil, partner: "Munkun",
                   location: "Zaragoza, Spain")
    Workshop.create!(
      slug: slug,
      title_translations: { "en" => "IMASUS Spain" },
      description_translations: { "en" => "A workshop in Zaragoza." },
      partner: partner,
      location: location,
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28),
      contact_email: contact_email
    )
  end

  def make_published_project(workshop:, title:, published_at: Time.current)
    user = User.create!(
      name: "Author #{title}",
      email: "author-#{SecureRandom.hex(4)}@example.com",
      password: @password,
      role: :participant
    )
    project = Project.create!(workshop: workshop, title: title, language: "en", status: "draft")
    ProjectMembership.create!(project: project, user: user)
    project.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
    project.process_summary = "<p>Process for #{title}.</p>"
    project.status = "published"
    project.save!
    project.update_column(:publication_updated_at, published_at)
    project
  end

  # ---------------------------------------------------------------------
  # Visitor variant
  # ---------------------------------------------------------------------

  test "GET / renders the visitor variant when no user is signed in" do
    get root_url
    assert_response :success
    assert_select "[data-home-variant=visitor]"
  end

  test "visitor home shows the See workshops and Log in CTAs" do
    get root_url
    assert_select "a", text: I18n.t("home.visitor.hero.see_workshops")
    assert_select "a[href=?]", new_session_path, text: I18n.t("home.visitor.hero.log_in")
  end

  test "visitor home lists every workshop with title, location, and dates" do
    workshop = make_workshop
    get root_url
    assert_select "[data-workshop-card][data-slug=?]", workshop.slug do
      assert_select "*", text: /IMASUS Spain/
      assert_select "*", text: /Zaragoza, Spain/
    end
  end

  test "workshop with contact_email shows a Request a spot mailto: CTA" do
    workshop = make_workshop(contact_email: "spain@imasus.eu")
    get root_url
    assert_select "[data-workshop-card][data-slug=?]", workshop.slug do
      assert_select "a[href=?]", "mailto:spain@imasus.eu",
                    text: I18n.t("home.visitor.workshops.request_spot")
    end
  end

  test "workshop without contact_email omits the Request a spot CTA" do
    workshop = make_workshop(slug: "italy-2026", contact_email: nil,
                             partner: "Lottozero", location: "Prato, Italy")
    get root_url
    assert_select "[data-workshop-card][data-slug=?]", workshop.slug do
      assert_select "a[href^=?]", "mailto:", count: 0
    end
  end

  test "visitor home shows up to six most-recently-published projects" do
    workshop = make_workshop
    7.times do |i|
      make_published_project(
        workshop: workshop,
        title: "Project #{i}",
        published_at: i.hours.ago
      )
    end

    get root_url
    assert_select "[data-featured-project]", count: 6
  end

  test "visitor home renders empty placeholder when no published projects exist" do
    get root_url
    assert_select "[data-featured-project]", count: 0
    assert_select "[data-featured-projects-empty]"
  end

  test "visitor home renders four public-resource teaser cards" do
    get root_url
    assert_select "[data-resource-card][data-resource=materials]"
    assert_select "[data-resource-card][data-resource=training]"
    assert_select "[data-resource-card][data-resource=glossary]"
    assert_select "[data-resource-card][data-resource=challenges]"
  end

  # ---------------------------------------------------------------------
  # Participant variant
  # ---------------------------------------------------------------------

  def make_participant(email: "p-#{SecureRandom.hex(4)}@example.com")
    User.create!(name: "Pablo", email: email, password: @password, role: :participant)
  end

  def attach_to_workshop(user, workshop)
    WorkshopParticipation.create!(user: user, workshop: workshop)
  end

  def make_draft_project(workshop:, user:, title: "Draft project")
    project = Project.create!(workshop: workshop, title: title, language: "en", status: "draft")
    ProjectMembership.create!(project: project, user: user)
    project
  end

  def publish!(project, author:)
    project.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
    project.process_summary = "<p>Story</p>"
    project.status = "published"
    project.save!
    project
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "GET / renders the participant variant for a participant user" do
    user = make_participant
    sign_in(user)
    get root_url
    assert_select "[data-home-variant=participant]"
  end

  test "participant with no workshops sees the facilitator-setup message" do
    user = make_participant
    sign_in(user)
    get root_url
    assert_select "[data-empty-state=no-workshops]"
  end

  test "participant with workshops but no projects sees the workshops-strip prompt" do
    user = make_participant
    workshop = make_workshop(slug: "italy-2026", partner: "Lottozero", location: "Prato, Italy")
    attach_to_workshop(user, workshop)
    sign_in(user)
    get root_url
    assert_select "[data-empty-state=no-projects]"
    assert_select "[data-workshop-strip] *", text: /Prato, Italy/
  end

  test "draft project with zero log entries shows the Add your first log entry CTA" do
    user = make_participant
    workshop = make_workshop
    attach_to_workshop(user, workshop)
    project = make_draft_project(workshop: workshop, user: user, title: "Alpha")
    sign_in(user)
    get root_url
    assert_select "[data-project-card][data-project-id=?]", project.id.to_s do
      assert_select "a[href=?]", new_project_log_entry_path(project),
                    text: I18n.t("home.participant.cta.add_first_log_entry")
    end
  end

  test "draft project with at least one log entry shows Continue your log primary and Publish secondary" do
    user = make_participant
    workshop = make_workshop
    attach_to_workshop(user, workshop)
    project = make_draft_project(workshop: workshop, user: user, title: "Beta")
    LogEntry.create!(project: project, author: user, body: "First update.")
    sign_in(user)
    get root_url
    assert_select "[data-project-card][data-project-id=?]", project.id.to_s do
      assert_select "a[href=?]", project_log_entries_path(project),
                    text: I18n.t("home.participant.cta.continue_log")
      assert_select "a[href=?]", new_project_publication_path(project),
                    text: I18n.t("home.participant.cta.publish")
    end
  end

  test "published project shows View public page primary and Edit publication secondary" do
    user = make_participant
    workshop = make_workshop
    attach_to_workshop(user, workshop)
    project = make_draft_project(workshop: workshop, user: user, title: "Gamma")
    publish!(project, author: user)

    sign_in(user)
    get root_url
    assert_select "[data-project-card][data-project-id=?]", project.id.to_s do
      assert_select "a[href=?]", published_project_path(slug: project.slug),
                    text: I18n.t("home.participant.cta.view_public")
      assert_select "a[href=?]", edit_project_publication_path(project),
                    text: I18n.t("home.participant.cta.edit_publication")
    end
  end
end
