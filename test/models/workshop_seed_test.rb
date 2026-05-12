require "test_helper"

class WorkshopSeedTest < ActiveSupport::TestCase
  test "seed_from_yaml loads the current workshop seed set idempotently" do
    assert_difference -> { Workshop.count }, 1 do
      Workshop.seed_from_yaml!
    end

    workshop = Workshop.find_by!(slug: "spain")
    assert_equal Date.new(2026, 4, 28), workshop.starts_on
    assert_equal Date.new(2026, 4, 28), workshop.ends_on

    I18n.with_locale(:es) do
      assert workshop.title.present?
      assert workshop.description.present?
      assert_includes workshop.agenda_es.body.to_plain_text.to_s, "Sesion 1"
    end

    assert_no_difference -> { Workshop.count } do
      Workshop.seed_from_yaml!
    end
  end

  test "seed_from_yaml loads contact_email when present in the seed entry" do
    Workshop.seed_from_yaml!
    workshop = Workshop.find_by!(slug: "spain")
    assert_equal "spain@imasus.eu", workshop.contact_email
  end

  test "seed_from_yaml preserves edited agenda and metadata by default" do
    Workshop.seed_from_yaml!
    workshop = Workshop.find_by!(slug: "spain")
    workshop.update!(
      title_translations: { "es" => "Titulo editado" },
      contact_email: "edited@example.com",
      location: "Edited location"
    )
    workshop.agenda_es = "<h2>Agenda editada</h2><p>Texto propio.</p>"
    workshop.save!

    Workshop.seed_from_yaml!
    workshop.reload

    assert_equal "Titulo editado", workshop.title_translations["es"]
    assert_equal "edited@example.com", workshop.contact_email
    assert_equal "Edited location", workshop.location
    assert_includes workshop.agenda_es.body.to_plain_text.to_s, "Agenda editada"
  end

  test "seed_from_yaml overwrites edited agenda and metadata when requested" do
    Workshop.seed_from_yaml!
    workshop = Workshop.find_by!(slug: "spain")
    workshop.update!(
      title_translations: { "es" => "Titulo editado" },
      contact_email: "edited@example.com"
    )
    workshop.agenda_es = "<h2>Agenda editada</h2><p>Texto propio.</p>"
    workshop.save!

    Workshop.seed_from_yaml!(overwrite: true)
    workshop.reload

    assert_equal "Taller IMASUS Espana", workshop.title_translations["es"]
    assert_equal "spain@imasus.eu", workshop.contact_email
    assert_includes workshop.agenda_es.body.to_plain_text.to_s, "Sesion 1"
  end

  test "seed_from_yaml only prunes unseeded workshops when overwriting" do
    Workshop.create!(
      slug: "manual",
      title_translations: { "en" => "Manual" },
      description_translations: { "en" => "Created in production." },
      location: "Manual location",
      starts_on: Date.new(2026, 5, 1),
      ends_on: Date.new(2026, 5, 2)
    )

    Workshop.seed_from_yaml!
    assert Workshop.exists?(slug: "manual")

    Workshop.seed_from_yaml!(overwrite: true)
    assert_not Workshop.exists?(slug: "manual")
  end
end
