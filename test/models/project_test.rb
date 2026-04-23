require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @workshop = Workshop.create!(
      slug: "spain-2026",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      partner: "Munkun",
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @admin       = User.create!(name: "Admin",    email: "admin@example.com",    role: :admin)
    @facilitator = User.create!(name: "Fac",      email: "fac@example.com",      role: :facilitator)
    @member      = User.create!(name: "Member",   email: "member@example.com",   role: :participant)
    @outsider    = User.create!(name: "Outsider", email: "outsider@example.com", role: :participant)

    WorkshopParticipation.create!(user: @member, workshop: @workshop)

    @project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: @project, user: @member)
  end

  # --- Validations ---

  test "valid with required attributes" do
    project = Project.new(workshop: @workshop, title: "Test", language: "en", status: "draft")
    assert project.valid?
  end

  test "requires title" do
    project = Project.new(workshop: @workshop, language: "en", status: "draft")
    assert_not project.valid?
    assert_includes project.errors[:title], "can't be blank"
  end

  test "requires workshop" do
    project = Project.new(title: "Test", language: "en", status: "draft")
    assert_not project.valid?
    assert_includes project.errors[:workshop], "must exist"
  end

  test "rejects blank language when explicitly set" do
    project = Project.new(workshop: @workshop, title: "Test", status: "draft", language: "")
    assert_not project.valid?
    assert_includes project.errors[:language], "can't be blank"
  end

  test "rejects language outside allowed list" do
    project = Project.new(workshop: @workshop, title: "Test", language: "fr", status: "draft")
    assert_not project.valid?
    assert_includes project.errors[:language], "is not included in the list"
  end

  test "accepts all four allowed languages" do
    %w[en es it el].each do |lang|
      project = Project.new(workshop: @workshop, title: "Test", language: lang, status: "draft")
      assert project.valid?, "expected language '#{lang}' to be valid"
    end
  end

  test "only draft is a valid status for now" do
    project = Project.new(workshop: @workshop, title: "Test", language: "en", status: "published")
    assert_not project.valid?
    assert_includes project.errors[:status], "is not included in the list"
  end

  test "status defaults to draft" do
    project = Project.new(workshop: @workshop, title: "Test", language: "en")
    assert_equal "draft", project.status
  end

  # --- Language default from workshop ---

  test "language defaults from workshop communication_locale when not supplied" do
    project = Project.new(workshop: @workshop, title: "Test")
    assert_equal @workshop.communication_locale, project.language
  end

  # --- Associations ---

  test "belongs to challenge optionally" do
    project = Project.new(workshop: @workshop, title: "Test", language: "en", status: "draft")
    assert project.valid?
    assert_nil project.challenge
  end

  test "has many memberships and members through memberships" do
    assert_includes @project.members.reload, @member
  end

  test "destroying project cascades memberships" do
    membership_id = ProjectMembership.find_by(project: @project, user: @member).id
    @project.destroy!
    assert_nil ProjectMembership.find_by(id: membership_id)
  end

  # --- visible_to? ---

  test "visible_to? is true for a member" do
    assert @project.visible_to?(@member)
  end

  test "visible_to? is true for a facilitator" do
    assert @project.visible_to?(@facilitator)
  end

  test "visible_to? is true for an admin" do
    assert @project.visible_to?(@admin)
  end

  test "visible_to? is false for a non-member participant" do
    assert_not @project.visible_to?(@outsider)
  end

  test "visible_to? is false for nil (visitor)" do
    assert_not @project.visible_to?(nil)
  end

  # --- editable_by? ---

  test "editable_by? is true for a member" do
    assert @project.editable_by?(@member)
  end

  test "editable_by? is true for an admin" do
    assert @project.editable_by?(@admin)
  end

  test "editable_by? is false for a facilitator" do
    assert_not @project.editable_by?(@facilitator)
  end

  test "editable_by? is false for a non-member participant" do
    assert_not @project.editable_by?(@outsider)
  end

  test "editable_by? is false for nil" do
    assert_not @project.editable_by?(nil)
  end
end
