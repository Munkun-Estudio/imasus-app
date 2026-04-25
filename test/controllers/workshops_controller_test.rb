require "test_helper"

class WorkshopsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @workshop = Workshop.create!(
      slug: "spain",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
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

  test "public show excludes disabled published projects" do
    visible = Project.create!(workshop: @workshop, title: "Visible", language: "es", status: "draft")
    hidden  = Project.create!(workshop: @workshop, title: "Disabled Project", language: "es", status: "draft")
    [ visible, hidden ].each { |p| ProjectMembership.create!(project: p, user: @participant) }
    publish_project!(visible)
    publish_project!(hidden)

    admin = User.create!(name: "Admin", email: "admin-wsx@example.com",
                          password: "correct horse battery staple", role: :admin)
    hidden.disable!(by: admin)

    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", published_project_path(slug: visible.slug)
    assert_select "a[href=?]", published_project_path(slug: hidden.slug), count: 0
  end

  # ---------------------------------------------------------------------
  # Workshop edit (spec 13)
  # ---------------------------------------------------------------------

  def make_admin
    User.create!(name: "Admin", email: "ws-admin@example.com", password: @password, role: :admin)
  end

  def make_participating_facilitator(workshop:)
    fac = User.create!(name: "Elena", email: "ws-elena-#{SecureRandom.hex(2)}@example.com",
                       password: @password, role: :facilitator)
    WorkshopParticipation.create!(user: fac, workshop: workshop)
    fac
  end

  test "GET edit redirects unauthenticated users to login" do
    get edit_workshop_url(@workshop)
    assert_redirected_to new_session_path
  end

  test "GET edit redirects participants with access denied" do
    sign_in(@participant)
    get edit_workshop_url(@workshop)
    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end

  test "GET edit redirects a facilitator who does not participate in this workshop" do
    sign_in(@facilitator) # facilitator without WorkshopParticipation
    get edit_workshop_url(@workshop)
    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end

  test "GET edit renders for an admin" do
    sign_in(make_admin)
    get edit_workshop_url(@workshop)
    assert_response :success
  end

  test "GET edit renders for a facilitator who participates in the workshop" do
    sign_in(make_participating_facilitator(workshop: @workshop))
    get edit_workshop_url(@workshop)
    assert_response :success
  end

  test "PATCH update persists translated, plain, and contact fields" do
    sign_in(make_admin)
    patch workshop_url(@workshop), params: {
      workshop: {
        title_translations: { "es" => "Nuevo título", "en" => "New title" },
        description_translations: { "es" => "Nueva descripción", "en" => "New description" },
        location: "Madrid, Spain",
        starts_on: "2027-01-01",
        ends_on: "2027-01-02",
        contact_email: "hello@imasus.eu"
      }
    }
    assert_redirected_to workshop_url(@workshop)

    @workshop.reload
    assert_equal "Nuevo título",       @workshop.title_translations["es"]
    assert_equal "New title",          @workshop.title_translations["en"]
    assert_equal "Madrid, Spain",      @workshop.location
    assert_equal Date.new(2027, 1, 1), @workshop.starts_on
    assert_equal Date.new(2027, 1, 2), @workshop.ends_on
    assert_equal "hello@imasus.eu",    @workshop.contact_email
  end

  test "PATCH update rejects ends_on before starts_on" do
    sign_in(make_admin)
    patch workshop_url(@workshop), params: {
      workshop: { starts_on: "2027-02-01", ends_on: "2027-01-15" }
    }
    assert_response :unprocessable_content
    @workshop.reload
    assert_not_equal Date.new(2027, 2, 1), @workshop.starts_on
  end

  test "PATCH update rejects malformed contact_email" do
    sign_in(make_admin)
    patch workshop_url(@workshop), params: {
      workshop: { contact_email: "not-an-email" }
    }
    assert_response :unprocessable_content
    @workshop.reload
    assert_nil @workshop.contact_email
  end

  test "PATCH update is blocked for non-managers" do
    sign_in(@participant)
    patch workshop_url(@workshop), params: {
      workshop: { location: "Hijacked Town" }
    }
    assert_redirected_to root_path
    @workshop.reload
    assert_not_equal "Hijacked Town", @workshop.location
  end

  test "edit form does not expose an editable slug field" do
    sign_in(make_admin)
    get edit_workshop_url(@workshop)
    assert_response :success
    assert_select "input[name='workshop[slug]']", count: 0
  end

  test "edit form renders four agenda Trix editors, one per locale" do
    sign_in(make_admin)
    get edit_workshop_url(@workshop)
    assert_response :success
    assert_select "trix-editor", count: 4
    %w[en es it el].each do |locale|
      assert_select "input[type=hidden][name=?]", "workshop[agenda_#{locale}]"
    end
  end

  # ---------------------------------------------------------------------
  # Workshop creation (workshop-management spec)
  # ---------------------------------------------------------------------

  test "GET new redirects unauthenticated users to login" do
    get new_workshop_url
    assert_redirected_to new_session_path
  end

  test "GET new redirects participants with access denied" do
    sign_in(@participant)
    get new_workshop_url
    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end

  test "GET new renders for admin" do
    sign_in(make_admin)
    get new_workshop_url
    assert_response :success
    assert_select "form[action=?]", workshops_path
  end

  test "GET new renders for any facilitator regardless of prior workshop participations" do
    fac = User.create!(name: "New Fac", email: "newfac@example.com",
                       password: @password, role: :facilitator)
    sign_in(fac)
    get new_workshop_url
    assert_response :success
  end

  test "POST create persists workshop and auto-attaches the creator as a workshop participation" do
    fac = User.create!(name: "Beatriz", email: "beatriz@example.com",
                       password: @password, role: :facilitator)
    sign_in(fac)

    assert_difference -> { Workshop.count }, 1 do
      assert_difference -> { WorkshopParticipation.count }, 1 do
        post workshops_path, params: {
          workshop: {
            title_translations: { "en" => "Portugal Workshop" },
            description_translations: { "en" => "An IMASUS workshop in Lisbon." },
            location: "Lisbon, Portugal",
            starts_on: "2027-01-15",
            ends_on: "2027-01-16",
            contact_email: "portugal@imasus.eu"
          }
        }
      end
    end

    workshop = Workshop.find_by!(slug: "portugal-workshop")
    assert_redirected_to workshop_path(workshop)
    assert WorkshopParticipation.exists?(user: fac, workshop: workshop),
           "creator should be auto-attached as a workshop participation"
    assert workshop.manageable_by?(fac), "creator should immediately be able to manage"
  end

  test "POST create renders new with 422 when validations fail" do
    sign_in(make_admin)
    post workshops_path, params: {
      workshop: {
        title_translations: {},
        description_translations: {},
        location: "",
        starts_on: nil,
        ends_on: nil
      }
    }
    assert_response :unprocessable_content
  end

  test "POST create forbidden for participants" do
    sign_in(@participant)
    assert_no_difference -> { Workshop.count } do
      post workshops_path, params: {
        workshop: {
          title_translations: { "en" => "Hijack" },
          description_translations: { "en" => "Hijack." },
          location: "Nowhere",
          starts_on: "2027-02-01",
          ends_on: "2027-02-01"
        }
      }
    end
    assert_redirected_to root_path
  end

  test "PATCH update persists per-locale agenda content" do
    sign_in(make_admin)
    patch workshop_url(@workshop), params: {
      workshop: {
        agenda_en: "<h2>Spec 14 agenda EN</h2>",
        agenda_es: "<h2>Agenda ES</h2>"
      }
    }
    assert_redirected_to workshop_url(@workshop)
    @workshop.reload
    assert_includes @workshop.agenda_en.body.to_s, "Spec 14 agenda EN"
    assert_includes @workshop.agenda_es.body.to_s, "Agenda ES"
  end

  test "workshop show page renders an Edit workshop link for managers" do
    sign_in(make_admin)
    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", edit_workshop_path(@workshop), text: I18n.t("workshops.show.edit_workshop")
  end

  test "workshop show page hides the Edit workshop link from non-managers" do
    sign_in(@participant)
    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", edit_workshop_path(@workshop), count: 0
  end

  test "workshop show page hides the Edit workshop link from visitors" do
    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", edit_workshop_path(@workshop), count: 0
  end

  test "public index published count excludes disabled projects" do
    visible = Project.create!(workshop: @workshop, title: "Visible Counted", language: "es", status: "draft")
    hidden  = Project.create!(workshop: @workshop, title: "Hidden Counted",  language: "es", status: "draft")
    [ visible, hidden ].each { |p| ProjectMembership.create!(project: p, user: @participant) }
    publish_project!(visible)
    publish_project!(hidden)

    admin = User.create!(name: "Admin", email: "admin-wsi@example.com",
                          password: "correct horse battery staple", role: :admin)
    hidden.disable!(by: admin)

    get workshops_url
    assert_response :success
    assert_select "dd", text: I18n.t("workshops.index.published_project_count", count: 1), minimum: 1
  end
end
