require "test_helper"

class ParticipantInvitationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @workshop = Workshop.create!(
      slug: "spain",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      partner: "Munkun",
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @participant = User.create!(name: "P", email: "p@example.com", role: :participant)
    @participant.generate_invitation_token!
    WorkshopParticipation.create!(user: @participant, workshop: @workshop)
    @token = @participant.invitation_token
  end

  test "GET edit with valid token renders" do
    get edit_participant_invitation_path(token: @token)
    assert_response :success
    assert_select "h1", text: I18n.t("participant_invitations.edit.title")
    assert_select "input[type=email][class*=?]", "border"
    assert_select "h2", text: I18n.t("participant_invitations.edit.profile_heading")
    assert_select "p", text: I18n.t("participant_invitations.edit.profile_lead")
    assert_select "textarea[class*=?]", "border", minimum: 2
    assert_select "select[name=?]", "user[country]"
    assert_select "option[value=?]", "Spain"
    assert_select "option[value=?]", "Italy"
    assert_select "option[value=?]", "Greece"
    assert_select "button[aria-label=?]", I18n.t("participant_invitations.edit.bio_hint")
    assert_select "button[aria-label=?]", I18n.t("participant_invitations.edit.links_hint")
    assert_select "input[type=password][class*=?]", "border", count: 1
    assert_select "input[name=?]", "user[password_confirmation]", count: 0
    assert_select "div.mx-auto.max-w-2xl", count: 0
  end

  test "GET edit can render in the invitation locale" do
    get edit_participant_invitation_path(token: @token, locale: :es)
    assert_response :success
    assert_select "h1", text: I18n.t("participant_invitations.edit.title", locale: :es)
    assert_select "p", text: "Taller IMASUS Espana"
  end

  test "GET edit with expired token redirects with error" do
    @participant.update!(invitation_sent_at: 15.days.ago)
    get edit_participant_invitation_path(token: @token)
    assert_redirected_to new_session_path
    assert_not_nil flash[:alert]
  end

  test "GET edit with unknown token redirects with error" do
    get edit_participant_invitation_path(token: "nope")
    assert_redirected_to new_session_path
  end

  test "PATCH update completes registration and redirects to workshop" do
    patch participant_invitation_path(token: @token), params: {
      user: {
        name: "Paula Participant",
        institution: "Uni",
        country: "Spain",
        bio: "Student of design.",
        links: "https://example.com/paula",
        password: "fresh password 42"
      }
    }

    @participant.reload
    assert_equal "Paula Participant", @participant.name
    assert_equal "Uni", @participant.institution
    assert_equal "Spain",  @participant.country
    assert @participant.authenticate("fresh password 42")
    assert_nil @participant.invitation_token
    assert_not_nil @participant.invitation_accepted_at
    assert_redirected_to workshop_path(@workshop)
    assert_equal @participant.id, session[:user_id]
  end

  test "PATCH update accepts a password without confirmation in this flow" do
    patch participant_invitation_path(token: @token), params: {
      user: {
        name: "Paula Participant",
        password: "fresh password 42"
      }
    }

    assert_redirected_to workshop_path(@workshop)
    assert @participant.reload.authenticate("fresh password 42")
  end

  test "PATCH update with missing required field re-renders" do
    patch participant_invitation_path(token: @token), params: {
      user: { name: "", password: "fresh password 42" }
    }
    assert_response :unprocessable_content
    @participant.reload
    assert @participant.invitation_token.present?
  end

  test "PATCH update with short password shows translated validation error" do
    patch participant_invitation_path(token: @token, locale: :es), params: {
      user: {
        name: "Paula Participant",
        password: "corta"
      }
    }

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /Contraseña es demasiado corta/
  end
end
