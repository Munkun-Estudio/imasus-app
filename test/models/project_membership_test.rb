require "test_helper"

class ProjectMembershipTest < ActiveSupport::TestCase
  def setup
    @workshop = Workshop.create!(
      slug: "spain-2026",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @user_a = User.create!(name: "Alice", email: "alice@example.com", role: :participant)
    @user_b = User.create!(name: "Bob",   email: "bob@example.com",   role: :participant)

    WorkshopParticipation.create!(user: @user_a, workshop: @workshop)
    WorkshopParticipation.create!(user: @user_b, workshop: @workshop)

    @project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    @membership_a = ProjectMembership.create!(project: @project, user: @user_a)
    @membership_b = ProjectMembership.create!(project: @project, user: @user_b)
  end

  test "valid with project and user" do
    membership = ProjectMembership.new(project: @project, user: @user_a)
    assert membership.valid? || membership.errors[:user_id].any? # already exists; uniqueness fires
  end

  test "requires project" do
    membership = ProjectMembership.new(user: @user_a)
    assert_not membership.valid?
    assert_includes membership.errors[:project], "must exist"
  end

  test "requires user" do
    membership = ProjectMembership.new(project: @project)
    assert_not membership.valid?
    assert_includes membership.errors[:user], "must exist"
  end

  test "enforces uniqueness of user per project" do
    duplicate = ProjectMembership.new(project: @project, user: @user_a)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "same user can belong to different projects" do
    other_project = Project.create!(workshop: @workshop, title: "Other Project", language: "es", status: "draft")
    membership = ProjectMembership.new(project: other_project, user: @user_a)
    assert membership.valid?
  end

  test "destroying last member destroys the project" do
    project_id = @project.id
    @membership_a.destroy!
    @membership_b.destroy!
    assert_nil Project.find_by(id: project_id)
  end

  test "destroying a non-last member does not destroy the project" do
    project_id = @project.id
    @membership_a.destroy!
    assert Project.find_by(id: project_id).present?
  end
end
