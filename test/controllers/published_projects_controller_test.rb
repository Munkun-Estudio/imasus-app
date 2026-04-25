require "test_helper"

class PublishedProjectsControllerTest < ActionDispatch::IntegrationTest
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
    @member   = User.create!(name: "Member",   email: "member@example.com",   password: @password, role: :participant)
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

  test "non-member logged-in user does not see edit link" do
    sign_in(@outsider)
    get published_project_url(slug: @published.slug)
    assert_response :success
    assert_select "a[href=?]", edit_project_publication_path(@published), count: 0
  end

  test "show returns 404 for a disabled published project" do
    admin = User.create!(name: "Admin", email: "admin-pp@example.com",
                          password: @password, role: :admin)
    @published.disable!(by: admin)

    get published_project_url(slug: @published.slug)
    assert_response :not_found
  end
end
