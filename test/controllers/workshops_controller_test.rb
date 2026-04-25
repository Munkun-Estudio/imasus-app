require "test_helper"

class WorkshopsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @workshop = Workshop.create!(
      slug: "spain",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      partner: "Munkun",
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @participant = User.create!(name: "Part", email: "part@example.com", password: @password, role: :participant)
    @facilitator = User.create!(name: "Fac", email: "fac@example.com", password: @password, role: :facilitator)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  def publish_project!(project, updated_at: Time.current)
    project.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
    project.process_summary = "<p>Summary</p>"
    project.status = "published"
    project.publication_updated_at = updated_at
    project.save!
    project
  end

  test "index is public" do
    get workshops_url
    assert_response :success
    assert_select "a[href=?]", workshop_path(@workshop)
    assert_select "a[href=?]", agenda_workshop_path(@workshop), count: 0
    assert_select "span", text: I18n.t("workshops.index.attending"), count: 0
  end

  test "show is public and hides private workshop affordances" do
    get workshop_url(@workshop)
    assert_response :success
    assert_select "h1", text: "Taller IMASUS Espana"
    assert_select "a[href=?]", agenda_workshop_path(@workshop), count: 0
    assert_select "a[href=?]", new_workshop_invitation_path(@workshop), count: 0
    assert_select "a[href=?]", new_project_path(workshop_id: @workshop.id), count: 0
  end

  test "agenda requires login" do
    get agenda_workshop_url(@workshop)
    assert_redirected_to new_session_path
  end

  test "signed-in participant can view index and show by slug" do
    sign_in(@participant)

    get workshops_url
    assert_response :success
    assert_select "a[href=?]", workshop_path(@workshop)
    assert_select "div.px-6.py-12", count: 1
    assert_select "div.mx-auto.max-w-6xl", count: 0

    get workshop_url(@workshop)
    assert_response :success
    assert_select "h1", text: "Taller IMASUS Espana"
    assert_select "a[href=?]", workshops_path, text: I18n.t("workshops.show.back_to_index")
    assert_select "a[href=?]", agenda_workshop_path(@workshop), count: 1
    assert_select "dt", text: I18n.t("workshops.show.agenda"), count: 0
    assert_select "div.px-6.py-12", count: 1
    assert_select "div.mx-auto.max-w-5xl", count: 0
    assert_select "a", text: I18n.t("workshops.show.invite_participants", default: "Invite participants"), count: 0
  end

  test "facilitator sees the invitation call to action" do
    sign_in(@facilitator)
    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", new_workshop_invitation_path(@workshop)
  end

  test "agenda renders and unknown slugs 404" do
    sign_in(@participant)

    get agenda_workshop_url(@workshop)
    assert_response :success

    get workshop_url("unknown")
    assert_response :not_found

    get agenda_workshop_url("unknown")
    assert_response :not_found
  end

  test "show renders the projects section listing workshop projects" do
    WorkshopParticipation.create!(user: @participant, workshop: @workshop)
    project = Project.create!(workshop: @workshop, title: "Kapok", language: "es", status: "draft")
    ProjectMembership.create!(project: project, user: @participant)

    sign_in(@participant)
    get workshop_url(@workshop)
    assert_response :success
    assert_select "[data-project-id='#{project.id}']"
    assert_select "[data-role='your-project']"
  end

  test "show projects section shows a published project linking to its public page" do
    WorkshopParticipation.create!(user: @participant, workshop: @workshop)
    project = Project.create!(workshop: @workshop, title: "Published Kapok", language: "es", status: "draft")
    ProjectMembership.create!(project: project, user: @participant)
    publish_project!(project)

    sign_in(@participant)
    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", published_project_path(slug: project.slug)
  end

  test "public show renders published projects and hides drafts" do
    published = Project.create!(workshop: @workshop, title: "Published Kapok", language: "es", status: "draft")
    ProjectMembership.create!(project: published, user: @participant)
    publish_project!(published)

    draft = Project.create!(workshop: @workshop, title: "Draft Kapok", language: "es", status: "draft")
    ProjectMembership.create!(project: draft, user: @participant)

    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", published_project_path(slug: published.slug), text: "Published Kapok"
    assert_select "span", text: "Draft Kapok", count: 0
    assert_select "a", text: "Draft Kapok", count: 0
    assert_select "[data-project-id='#{draft.id}']", count: 0
  end

  test "public show lists all published projects newest first" do
    older = Project.create!(workshop: @workshop, title: "Older Project", language: "es", status: "draft")
    newer = Project.create!(workshop: @workshop, title: "Newer Project", language: "es", status: "draft")
    [ older, newer ].each { |project| ProjectMembership.create!(project: project, user: @participant) }
    publish_project!(older, updated_at: 2.days.ago)
    publish_project!(newer, updated_at: 1.day.ago)

    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", published_project_path(slug: older.slug)
    assert_select "a[href=?]", published_project_path(slug: newer.slug)
    assert_operator @response.body.index("Newer Project"), :<, @response.body.index("Older Project")
  end

  test "public show has an empty state when no projects are published" do
    Project.create!(workshop: @workshop, title: "Draft Kapok", language: "es", status: "draft")

    get workshop_url(@workshop)
    assert_response :success
    assert_select "p", text: I18n.t("workshops.show.no_published_projects")
  end

  test "public index includes workshops with no published projects" do
    empty_workshop = Workshop.create!(
      slug: "italy",
      title_translations: { "it" => "Workshop IMASUS Italia" },
      description_translations: { "it" => "Un workshop IMASUS in Italia." },
      partner: "Lottozero",
      location: "Prato, Italy",
      starts_on: Date.new(2026, 5, 12),
      ends_on: Date.new(2026, 5, 12)
    )

    get workshops_url
    assert_response :success
    assert_select "a[href=?]", workshop_path(@workshop)
    assert_select "a[href=?]", workshop_path(empty_workshop)
    assert_select "dd", text: I18n.t("workshops.index.published_project_count", count: 0), minimum: 1
  end

  test "show falls back to another available locale when current locale is missing" do
    get workshop_url(@workshop), params: { locale: :en }
    assert_response :success
    assert_select "h1", text: "Taller IMASUS Espana"
  end
end
