require "test_helper"

class WorkshopTest < ActiveSupport::TestCase
  def workshop_attributes(overrides = {})
    {
      slug: "spain-2026",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
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

  test "requires dates" do
    workshop = Workshop.new(workshop_attributes(starts_on: nil, ends_on: nil))
    assert_not workshop.valid?
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
                                                     location: "Prato, Italy"))
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

  # --- creatable_by? (workshop-management spec) ---

  test "creatable_by? is true for admin" do
    admin = User.create!(name: "A", email: "create-a@example.com", role: :admin)
    assert Workshop.creatable_by?(admin)
  end

  test "creatable_by? is true for any facilitator regardless of workshop participations" do
    fac = User.create!(name: "F", email: "create-f@example.com", role: :facilitator)
    assert Workshop.creatable_by?(fac)
  end

  test "creatable_by? is false for participants and visitors" do
    participant = User.create!(name: "P", email: "create-p@example.com", role: :participant)
    assert_not Workshop.creatable_by?(participant)
    assert_not Workshop.creatable_by?(nil)
  end

  # --- slug auto-generation (workshop-management spec) ---

  test "slug auto-generated from title preferring en when available" do
    workshop = Workshop.new(workshop_attributes(slug: nil,
                                                title_translations: { "es" => "Taller Sevilla", "en" => "Sevilla Workshop" }))
    workshop.save!
    assert_equal "sevilla-workshop", workshop.slug
  end

  test "slug auto-generated falls through es, it, el when en is absent" do
    workshop = Workshop.new(workshop_attributes(slug: nil,
                                                title_translations: { "it" => "Workshop Prato" }))
    workshop.save!
    assert_equal "workshop-prato", workshop.slug
  end

  test "slug collision is resolved with -2, -3 suffix" do
    Workshop.create!(workshop_attributes(slug: "demo",
                                          title_translations: { "en" => "Demo" }))
    second = Workshop.new(workshop_attributes(slug: nil,
                                              title_translations: { "en" => "Demo" }))
    second.save!
    assert_equal "demo-2", second.slug

    third = Workshop.new(workshop_attributes(slug: nil,
                                             title_translations: { "en" => "Demo" }))
    third.save!
    assert_equal "demo-3", third.slug
  end

  test "slug truncated to max 100 characters before collision suffix" do
    long_title = "x" * 200
    workshop = Workshop.new(workshop_attributes(slug: nil,
                                                title_translations: { "en" => long_title }))
    workshop.save!
    assert workshop.slug.length <= 100
  end

  test "slug not regenerated on subsequent saves" do
    workshop = Workshop.new(workshop_attributes(slug: nil,
                                                title_translations: { "en" => "Original" }))
    workshop.save!
    original = workshop.slug

    workshop.update!(title_translations: { "en" => "Different Title" })
    assert_equal original, workshop.reload.slug
  end
end
