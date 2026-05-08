require "test_helper"

class PublishedProjectsControllerTest < ActionDispatch::IntegrationTest
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
    @member   = User.create!(name: "Member",   email: "member@example.com",   password: @password, role: :participant,
                              institution: "Demo Institute", country: "ES", bio: "Works with biomaterials.",
                              links: "https://example.com/member")
    @outsider = User.create!(name: "Outsider", email: "outsider@example.com", password: @password, role: :participant)
    WorkshopParticipation.create!(user: @member, workshop: @workshop)

    @draft = Project.create!(workshop: @workshop, title: "Draft Only", language: "es", status: "draft")
    ProjectMembership.create!(project: @draft, user: @member)

    @published = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: @published, user: @member)
    @published.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
    @published.process_summary = "<p>Our journey</p>"
    @published.status = "published"
    @published.save!
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "show returns 200 for published project without auth" do
    get published_project_url(slug: @published.slug)
    assert_response :success
  end

  test "show renders public layout without application sidebar" do
    get published_project_url(slug: @published.slug)
    assert_response :success
    assert_select "aside", count: 0
    assert_select "nav[aria-label=?]", "Main navigation", count: 0
  end

  test "show returns 404 for unknown slug" do
    get published_project_url(slug: "nope-nope")
    assert_response :not_found
  end

  test "show returns 404 for a draft project slug-like path" do
    # Draft has no slug; force a request that should not resolve.
    get published_project_url(slug: "draft-only")
    assert_response :not_found
  end

  test "logged-in member sees edit link" do
    sign_in(@member)
    get published_project_url(slug: @published.slug)
    assert_response :success
    assert_select "a[href=?]", edit_project_publication_path(@published)
  end

  test "show renders participant profile cards in the team section" do
    get published_project_url(slug: @published.slug)
    assert_response :success

    assert_select "#published-project-team-heading", text: I18n.t("published_projects.show.members_heading")
    assert_select "[data-team-member=?]", @member.id.to_s do
      assert_select "h3", text: @member.name
      assert_select "*", text: /Demo Institute/
      assert_select "*", text: /Works with biomaterials/
      assert_select "a[href=?]", "https://example.com/member", text: "example.com"
    end
  end

  test "non-member logged-in user does not see edit link" do
    sign_in(@outsider)
    get published_project_url(slug: @published.slug)
    assert_response :success
    assert_select "a[href=?]", edit_project_publication_path(@published), count: 0
  end

  test "show wraps the process summary in trix-content without a redundant prose wrapper" do
    get published_project_url(slug: @published.slug)
    assert_response :success

    # ActionText emits the body inside <div class="trix-content">. The published
    # page should rely on .trix-content styling rather than wrap it again in
    # `prose`, which has no rules for the <div>-as-paragraph markup that Trix
    # produces and only adds noise.
    assert_select ".trix-content"
    assert_select ".prose .trix-content", count: 0
  end

  test "show renders the challenge as a full card linking to the challenges page" do
    challenge = Challenge.create!(
      code: "C6",
      category: "material",
      question_translations: { "en" => "How might we replace plastics?" },
      description_translations: { "en" => "Framing description for C6." }
    )
    @published.update!(challenge: challenge)

    get published_project_url(slug: @published.slug)
    assert_response :success

    assert_select "article[data-challenge=?]", "C6" do
      assert_select "h3 a[href=?]", challenges_path
      assert_select "a[data-turbo-frame=preview]", count: 0
    end
  end

  test "show hides the challenge bookmark toggle even when logged in" do
    challenge = Challenge.create!(
      code: "C7",
      category: "design",
      question_translations: { "en" => "How might we ..." },
      description_translations: { "en" => "..." }
    )
    @published.update!(challenge: challenge)
    sign_in(@member)

    get published_project_url(slug: @published.slug)
    assert_response :success

    assert_select "article[data-challenge=?]", "C7" do
      assert_select ".bookmark-toggle", count: 0
    end
  end

  test "show returns 404 for a disabled published project" do
    admin = User.create!(name: "Admin", email: "admin-pp@example.com",
                          password: @password, role: :admin)
    @published.disable!(by: admin)

    get published_project_url(slug: @published.slug)
    assert_response :not_found
  end
end
