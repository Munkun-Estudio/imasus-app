require "test_helper"

class WorkshopTest < ActiveSupport::TestCase
  def workshop_attributes(overrides = {})
    {
      slug: "spain-2026",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      partner: "Munkun",
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    }.merge(overrides)
  end

  test "valid with translated title and description plus workshop metadata" do
    workshop = Workshop.new(workshop_attributes)
    assert workshop.valid?
  end

  test "requires a translated title in at least one locale" do
    workshop = Workshop.new(workshop_attributes(title_translations: {}))
    assert_not workshop.valid?
    assert_includes workshop.errors[:title_translations], "can't be blank"
  end

  test "requires a translated description in at least one locale" do
    workshop = Workshop.new(workshop_attributes(description_translations: {}))
    assert_not workshop.valid?
    assert_includes workshop.errors[:description_translations], "can't be blank"
  end

  test "requires partner and dates" do
    workshop = Workshop.new(workshop_attributes(partner: nil, starts_on: nil, ends_on: nil))
    assert_not workshop.valid?
    assert_includes workshop.errors[:partner], "can't be blank"
    assert_includes workshop.errors[:starts_on], "can't be blank"
    assert_includes workshop.errors[:ends_on], "can't be blank"
  end

  test "requires ends_on to be on or after starts_on" do
    workshop = Workshop.new(workshop_attributes(starts_on: Date.new(2026, 4, 29), ends_on: Date.new(2026, 4, 28)))
    assert_not workshop.valid?
    assert_includes workshop.errors[:ends_on], "must be on or after the start date"
  end

  test "falls back to another available locale for translated fields" do
    workshop = Workshop.new(workshop_attributes)

    I18n.with_locale(:en) do
      assert_equal "Taller IMASUS Espana", workshop.title
      assert_equal "Un taller IMASUS en Zaragoza.", workshop.description
    end
  end

  test "communication locale prefers the workshop local language when present" do
    workshop = Workshop.new(workshop_attributes(title_translations: { "es" => "Taller IMASUS Espana", "en" => "IMASUS Spain Workshop" },
                                                description_translations: { "es" => "Un taller IMASUS en Zaragoza.", "en" => "An IMASUS workshop in Zaragoza." }))

    assert_equal "es", workshop.communication_locale
  end

  test "to_param returns the slug" do
    workshop = Workshop.new(workshop_attributes)
    assert_equal "spain-2026", workshop.to_param
  end

  test "has many participations and participants" do
    workshop = Workshop.create!(workshop_attributes(slug: "italy-2026", title_translations: { "it" => "Workshop IMASUS Italia" },
                                                     description_translations: { "it" => "Un workshop a Prato." },
                                                     partner: "Lottozero", location: "Prato, Italy"))
    user = User.create!(name: "P", email: "p@example.com", role: :participant)
    WorkshopParticipation.create!(user: user, workshop: workshop)
    assert_includes workshop.participations.reload, WorkshopParticipation.last
    assert_includes workshop.participants.reload, user
  end

  test "contact_email is optional" do
    workshop = Workshop.new(workshop_attributes(contact_email: nil))
    assert workshop.valid?, workshop.errors.full_messages.to_sentence
  end

  test "contact_email accepts a valid email address" do
    workshop = Workshop.new(workshop_attributes(contact_email: "spain@imasus.eu"))
    assert workshop.valid?, workshop.errors.full_messages.to_sentence
  end

  test "contact_email rejects malformed addresses" do
    workshop = Workshop.new(workshop_attributes(contact_email: "not-an-email"))
    assert_not workshop.valid?
    assert_includes workshop.errors[:contact_email], "is invalid"
  end

  # --- manageable_by? (spec 13) ---

  test "manageable_by? is true for any admin" do
    workshop = Workshop.create!(workshop_attributes)
    admin = User.create!(name: "A", email: "manage-a@example.com", role: :admin)
    assert workshop.manageable_by?(admin)
  end

  test "manageable_by? is true for a facilitator who participates in the workshop" do
    workshop = Workshop.create!(workshop_attributes)
    fac = User.create!(name: "F", email: "manage-f@example.com", role: :facilitator)
    WorkshopParticipation.create!(user: fac, workshop: workshop)
    assert workshop.manageable_by?(fac)
  end

  test "manageable_by? is false for a facilitator who does not participate" do
    workshop = Workshop.create!(workshop_attributes)
    other_workshop = Workshop.create!(workshop_attributes(slug: "italy",
                                                          partner: "Lottozero",
                                                          location: "Prato",
                                                          title_translations: { "it" => "Workshop Italia" },
                                                          description_translations: { "it" => "Italia." }))
    fac = User.create!(name: "F", email: "manage-fo@example.com", role: :facilitator)
    WorkshopParticipation.create!(user: fac, workshop: other_workshop)
    assert_not workshop.manageable_by?(fac)
  end

  test "manageable_by? is false for participants and visitors" do
    workshop = Workshop.create!(workshop_attributes)
    participant = User.create!(name: "P", email: "manage-p@example.com", role: :participant)
    WorkshopParticipation.create!(user: participant, workshop: workshop)

    assert_not workshop.manageable_by?(participant)
    assert_not workshop.manageable_by?(nil)
  end
end
