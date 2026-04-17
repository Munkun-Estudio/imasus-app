require "test_helper"

class WorkshopParticipationTest < ActiveSupport::TestCase
  def setup
    @user     = User.create!(name: "P", email: "p@example.com", role: :participant)
    @workshop = Workshop.create!(title: "IMASUS Greece", location: "Greece")
  end

  test "valid with user and workshop" do
    assert WorkshopParticipation.new(user: @user, workshop: @workshop).valid?
  end

  test "requires user" do
    assert_not WorkshopParticipation.new(workshop: @workshop).valid?
  end

  test "requires workshop" do
    assert_not WorkshopParticipation.new(user: @user).valid?
  end

  test "enforces unique (user, workshop) pair" do
    WorkshopParticipation.create!(user: @user, workshop: @workshop)
    dup = WorkshopParticipation.new(user: @user, workshop: @workshop)
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "has already been taken"
  end
end
