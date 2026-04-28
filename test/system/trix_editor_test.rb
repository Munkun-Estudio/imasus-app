require "application_system_test_case"

class TrixEditorTest < ApplicationSystemTestCase
  def setup
    @password = "correct horse battery staple"
    @admin = User.create!(
      name: "Admin",
      email: "admin-trix@example.com",
      password: @password,
      role: :admin
    )
    @workshop = Workshop.create!(
      slug: "spain-2026",
      title_translations: { "en" => "IMASUS Spain" },
      description_translations: { "en" => "A workshop in Zaragoza." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
  end

  def sign_in_as(user)
    visit new_session_url
    fill_in "email",    with: user.email
    fill_in "password", with: @password
    click_button I18n.t("sessions.new.submit")
    assert_no_current_path new_session_path, wait: 5
  end

  test "agenda Trix editor exposes heading controls" do
    sign_in_as(@admin)
    visit edit_workshop_url(@workshop)

    editor = first("trix-editor", wait: 5)
    toolbar_id = editor["toolbar"]

    within("##{toolbar_id}") do
      assert_selector "button[data-trix-attribute='heading1']", text: "H1"
      assert_selector "button[data-trix-attribute='heading2']", text: "H2"
      assert_selector "button[data-trix-attribute='heading3']", text: "H3"
    end
  end
end
