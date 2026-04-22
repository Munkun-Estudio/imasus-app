require "test_helper"

class WorkshopsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @workshop = Workshop.create!(
      slug: "spain",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      partner: "Munkun",
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @participant = User.create!(name: "Part", email: "part@example.com", password: @password, role: :participant)
    @facilitator = User.create!(name: "Fac", email: "fac@example.com", password: @password, role: :facilitator)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "index requires login" do
    get workshops_url
    assert_redirected_to new_session_path
  end

  test "show requires login" do
    get workshop_url(@workshop)
    assert_redirected_to new_session_path
  end

  test "agenda requires login" do
    get agenda_workshop_url(@workshop)
    assert_redirected_to new_session_path
  end

  test "signed-in participant can view index and show by slug" do
    sign_in(@participant)

    get workshops_url
    assert_response :success
    assert_select "a[href=?]", workshop_path(@workshop)
    assert_select "div.px-6.py-12", count: 1
    assert_select "div.mx-auto.max-w-6xl", count: 0

    get workshop_url(@workshop)
    assert_response :success
    assert_select "h1", text: "Taller IMASUS Espana"
    assert_select "a[href=?]", workshops_path, text: I18n.t("workshops.show.back_to_index")
    assert_select "a[href=?]", agenda_workshop_path(@workshop), count: 1
    assert_select "dt", text: I18n.t("workshops.show.agenda"), count: 0
    assert_select "div.px-6.py-12", count: 1
    assert_select "div.mx-auto.max-w-5xl", count: 0
    assert_select "a", text: I18n.t("workshops.show.invite_participants", default: "Invite participants"), count: 0
  end

  test "facilitator sees the invitation call to action" do
    sign_in(@facilitator)
    get workshop_url(@workshop)
    assert_response :success
    assert_select "a[href=?]", new_workshop_invitation_path(@workshop)
  end

  test "agenda renders and unknown slugs 404" do
    sign_in(@participant)

    get agenda_workshop_url(@workshop)
    assert_response :success

    get workshop_url("unknown")
    assert_response :not_found

    get agenda_workshop_url("unknown")
    assert_response :not_found
  end

  test "show falls back to another available locale when current locale is missing" do
    sign_in(@participant)

    get workshop_url(@workshop), params: { locale: :en }
    assert_response :success
    assert_select "h1", text: "Taller IMASUS Espana"
  end
end
