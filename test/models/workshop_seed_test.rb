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
end
