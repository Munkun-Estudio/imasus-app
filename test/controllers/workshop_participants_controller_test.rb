require "test_helper"

class WorkshopParticipantsControllerTest < ActionDispatch::IntegrationTest
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
    @admin       = User.create!(name: "Admin", email: "wp-admin@example.com", password: @password, role: :admin)
    @facilitator = User.create!(name: "Elena", email: "wp-fac@example.com",   password: @password, role: :facilitator)
    @participant = User.create!(name: "Maria", email: "wp-part@example.com",  password: @password, role: :participant,
                                institution: "Demo Institute", country: "ES")
    WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    WorkshopParticipation.create!(user: @participant, workshop: @workshop)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "GET index requires login" do
    get workshop_participants_url(@workshop)
    assert_redirected_to new_session_path
  end

  test "GET index forbidden for participants" do
    sign_in(@participant)
    get workshop_participants_url(@workshop)
    assert_redirected_to root_path
  end

  test "GET index renders for an admin" do
    sign_in(@admin)
    get workshop_participants_url(@workshop)
    assert_response :success
    assert_select "[data-participant-row][data-user-id=?]", @participant.id.to_s do
      assert_select "*", text: /Maria/
      assert_select "*", text: /Demo Institute/
    end
  end

  test "GET index renders for a facilitator who manages this workshop" do
    sign_in(@facilitator)
    get workshop_participants_url(@workshop)
    assert_response :success
    assert_select "[data-participant-row][data-user-id=?]", @participant.id.to_s
  end

  test "GET index forbidden for a facilitator who does not manage this workshop" do
    other_workshop = Workshop.create!(
      slug: "italy",
      title_translations: { "it" => "Italia" },
      description_translations: { "it" => "Italia." },
      partner: "Lottozero", location: "Prato",
      starts_on: Date.current, ends_on: Date.current
    )
    other_fac = User.create!(name: "Other", email: "wp-other-fac@example.com",
                             password: @password, role: :facilitator)
    WorkshopParticipation.create!(user: other_fac, workshop: other_workshop)

    sign_in(other_fac)
    get workshop_participants_url(@workshop)
    assert_redirected_to root_path
  end

  test "DELETE destroy removes the WorkshopParticipation but leaves user and project memberships" do
    project = Project.create!(workshop: @workshop, title: "Maria's Project", language: "es", status: "draft")
    membership = ProjectMembership.create!(project: project, user: @participant)
    sign_in(@admin)

    assert_difference -> { WorkshopParticipation.count }, -1 do
      assert_no_difference -> { User.count } do
        assert_no_difference -> { ProjectMembership.count } do
          delete workshop_participant_url(@workshop, user_id: @participant.id)
        end
      end
    end
    assert User.exists?(@participant.id)
    assert ProjectMembership.exists?(membership.id)
  end

  test "DELETE destroy hides own-row remove for the current user" do
    sign_in(@facilitator)
    get workshop_participants_url(@workshop)
    assert_response :success
    assert_select "[data-participant-row][data-user-id=?]", @facilitator.id.to_s do
      assert_select "form[action=?]", workshop_participant_path(@workshop, user_id: @facilitator.id), count: 0
    end
  end

  test "DELETE destroy refuses to remove the current user" do
    sign_in(@facilitator)
    delete workshop_participant_url(@workshop, user_id: @facilitator.id)
    assert WorkshopParticipation.exists?(user: @facilitator, workshop: @workshop),
           "facilitator should not be able to remove themselves"
  end

  test "DELETE destroy refuses to remove an admin user" do
    WorkshopParticipation.create!(user: @admin, workshop: @workshop)
    sign_in(@facilitator)
    delete workshop_participant_url(@workshop, user_id: @admin.id)
    assert WorkshopParticipation.exists?(user: @admin, workshop: @workshop),
           "admin should not be removable from the participants list"
  end
end
