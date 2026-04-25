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
end
