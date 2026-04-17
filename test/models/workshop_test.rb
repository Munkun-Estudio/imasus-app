require "test_helper"

# Minimal Workshop model — a placeholder introduced by the authentication spec
# so the participant invitation flow has a real workshop to attach to. Spec 9
# (`workshops`) will flesh out the full model with dates, agenda, partner, etc.
class WorkshopTest < ActiveSupport::TestCase
  test "valid with title and location" do
    workshop = Workshop.new(title: "IMASUS Spain", location: "Spain")
    assert workshop.valid?
  end

  test "requires title" do
    assert_not Workshop.new(location: "Spain").valid?
  end

  test "requires location" do
    assert_not Workshop.new(title: "IMASUS Spain").valid?
  end

  test "has many participations and participants" do
    workshop = Workshop.create!(title: "IMASUS Italy", location: "Italy")
    user = User.create!(name: "P", email: "p@example.com", role: :participant)
    WorkshopParticipation.create!(user: user, workshop: workshop)
    assert_includes workshop.participations.reload, WorkshopParticipation.last
    assert_includes workshop.participants.reload, user
  end
end
