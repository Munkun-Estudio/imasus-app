require "test_helper"

class Admin::FacilitatorsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def setup
    @password = "correct horse battery staple"
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: @password, role: :admin)
    @facilitator = User.create!(name: "Fac", email: "fac@example.com", password: @password, role: :facilitator)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "unauthenticated GET index redirects to login" do
    get admin_facilitators_path
    assert_redirected_to new_session_path
  end

  test "facilitator is denied access" do
    sign_in(@facilitator)
    get admin_facilitators_path
    assert_redirected_to root_path
  end

  test "admin can see the index" do
    sign_in(@admin)
    get admin_facilitators_path
    assert_response :success
  end

  test "index links each row to the facilitator show page" do
    sign_in(@admin)
    get admin_facilitators_path
    assert_select "a[href=?]", admin_facilitator_path(@facilitator)
  end

  test "index shows a Revoke affordance for pending facilitators" do
    pending = User.create!(name: "Pending", email: "pending@example.com", password: @password, role: :facilitator,
                           invitation_token: "tok", invitation_sent_at: Time.current)
    sign_in(@admin)
    get admin_facilitators_path
    assert_select "a[href=?]", revoke_confirmation_admin_facilitator_path(pending)
  end

  test "index does not show a Revoke affordance for accepted facilitators" do
    accepted = User.create!(name: "Accepted", email: "accepted@example.com", password: @password, role: :facilitator,
                            invitation_accepted_at: Time.current)
    sign_in(@admin)
    get admin_facilitators_path
    assert_select "a[href=?]", revoke_confirmation_admin_facilitator_path(accepted), count: 0
  end

  test "admin can open the new form" do
    sign_in(@admin)
    get new_admin_facilitator_path
    assert_response :success
    assert_select "h1", text: I18n.t("admin.facilitators.new.title")
    assert_select "input[type=text][class*=?]", "border"
    assert_select "input[type=email][class*=?]", "border"
    assert_select "input[type=submit][class*=?]", "bg-imasus-dark-green"
  end

  test "admin creates a facilitator, sends invitation email, and redirects" do
    sign_in(@admin)
    assert_emails 1 do
      assert_difference -> { User.facilitator.count }, 1 do
        post admin_facilitators_path, params: { user: { name: "New Fac", email: "new@example.com" } }
      end
    end
    created = User.find_by(email: "new@example.com")
    assert created.facilitator?
    assert created.invitation_token.present?
    assert_redirected_to admin_facilitators_path
  end

  test "creation is rejected when email is already taken" do
    sign_in(@admin)
    assert_no_emails do
      assert_no_difference -> { User.count } do
        post admin_facilitators_path, params: { user: { name: "Dup", email: @facilitator.email } }
      end
    end
    assert_response :unprocessable_content
  end

  test "creation rejects invalid email format" do
    sign_in(@admin)
    assert_no_emails do
      post admin_facilitators_path, params: { user: { name: "N", email: "not-an-email" } }
    end
    assert_response :unprocessable_content
  end

  test "create with empty workshop_ids behaves like today" do
    sign_in(@admin)
    assert_emails 1 do
      assert_difference -> { User.facilitator.count }, 1 do
        assert_no_difference -> { WorkshopParticipation.count } do
          post admin_facilitators_path,
               params: { user: { name: "Solo", email: "solo@example.com" }, workshop_ids: [] }
        end
      end
    end
  end

  test "create with workshop_ids assigns participations in one transaction" do
    workshop = Workshop.create!(
      slug: "italy-2026-7",
      title_translations: { "it" => "Workshop Italia 7" },
      description_translations: { "it" => "Prato." },
      location: "Prato",
      starts_on: Date.new(2026, 6, 3),
      ends_on: Date.new(2026, 6, 5)
    )
    other = Workshop.create!(
      slug: "spain-2026-7",
      title_translations: { "es" => "Taller España 7" },
      description_translations: { "es" => "Zaragoza." },
      location: "Zaragoza",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    sign_in(@admin)
    assert_emails 1 do
      assert_difference -> { User.facilitator.count }, 1 do
        assert_difference -> { WorkshopParticipation.count }, 2 do
          post admin_facilitators_path,
               params: { user: { name: "Both", email: "both@example.com" },
                         workshop_ids: [ workshop.id.to_s, other.id.to_s ] }
        end
      end
    end
    created = User.find_by(email: "both@example.com")
    assert_includes created.workshops, workshop
    assert_includes created.workshops, other
  end

  test "create with invalid workshop_id rolls back user and participations" do
    sign_in(@admin)
    assert_no_emails do
      assert_no_difference -> { User.count } do
        assert_no_difference -> { WorkshopParticipation.count } do
          post admin_facilitators_path,
               params: { user: { name: "Bad", email: "bad@example.com" },
                         workshop_ids: [ "999999" ] }
        end
      end
    end
    assert_response :unprocessable_content
  end

  test "unauthenticated GET show redirects to login" do
    get admin_facilitator_path(@facilitator)
    assert_redirected_to new_session_path
  end

  test "facilitator role is denied access to show" do
    sign_in(@facilitator)
    get admin_facilitator_path(@facilitator)
    assert_redirected_to root_path
  end

  test "admin can see a facilitator show page" do
    sign_in(@admin)
    get admin_facilitator_path(@facilitator)
    assert_response :success
    assert_select "h1", text: @facilitator.name
  end

  test "unauthenticated DELETE on a facilitator redirects to login" do
    pending = User.create!(name: "Pending", email: "pending@example.com", password: @password, role: :facilitator,
                           invitation_token: "tok", invitation_sent_at: Time.current)
    assert_no_difference -> { User.count } do
      delete admin_facilitator_path(pending)
    end
    assert_redirected_to new_session_path
  end

  test "facilitator role denied from DELETE" do
    pending = User.create!(name: "Pending", email: "pending@example.com", password: @password, role: :facilitator,
                           invitation_token: "tok", invitation_sent_at: Time.current)
    sign_in(@facilitator)
    assert_no_difference -> { User.count } do
      delete admin_facilitator_path(pending)
    end
    assert_redirected_to root_path
  end

  test "admin revokes a pending facilitator invitation" do
    pending = User.create!(name: "Pending", email: "pending@example.com", password: @password, role: :facilitator,
                           invitation_token: "tok", invitation_sent_at: Time.current)
    sign_in(@admin)
    assert_difference -> { User.count }, -1 do
      delete admin_facilitator_path(pending)
    end
    assert_redirected_to admin_facilitators_path
  end

  test "revocation cascades pre-assigned WorkshopParticipation rows" do
    pending = User.create!(name: "Pending", email: "pending@example.com", password: @password, role: :facilitator,
                           invitation_token: "tok", invitation_sent_at: Time.current)
    workshop = Workshop.create!(
      slug: "italy-2026",
      title_translations: { "it" => "Workshop Italia" },
      description_translations: { "it" => "Prato." },
      location: "Prato",
      starts_on: Date.new(2026, 6, 3),
      ends_on: Date.new(2026, 6, 5)
    )
    WorkshopParticipation.create!(user: pending, workshop: workshop)
    sign_in(@admin)
    assert_difference -> { WorkshopParticipation.count }, -1 do
      delete admin_facilitator_path(pending)
    end
  end

  test "DELETE refuses to revoke an accepted facilitator" do
    accepted = User.create!(name: "Accepted", email: "accepted@example.com", password: @password, role: :facilitator,
                            invitation_accepted_at: Time.current)
    sign_in(@admin)
    assert_no_difference -> { User.count } do
      delete admin_facilitator_path(accepted)
    end
    assert_redirected_to admin_facilitator_path(accepted)
    assert flash[:alert].present?
  end

  test "admin can open revoke_confirmation modal for a pending facilitator" do
    pending = User.create!(name: "Pending", email: "pending@example.com", password: @password, role: :facilitator,
                           invitation_token: "tok", invitation_sent_at: Time.current)
    sign_in(@admin)
    get revoke_confirmation_admin_facilitator_path(pending)
    assert_response :success
    assert_select "turbo-frame#modal"
  end

  test "revoke_confirmation form breaks out of the modal frame on submit" do
    pending = User.create!(name: "Pending", email: "pending@example.com", password: @password, role: :facilitator,
                           invitation_token: "tok", invitation_sent_at: Time.current)
    sign_in(@admin)
    get revoke_confirmation_admin_facilitator_path(pending)
    assert_select "turbo-frame#modal form[data-turbo-frame=?]", "_top"
  end

  test "revoke_confirmation denied for facilitator role" do
    pending = User.create!(name: "Pending", email: "pending@example.com", password: @password, role: :facilitator,
                           invitation_token: "tok", invitation_sent_at: Time.current)
    sign_in(@facilitator)
    get revoke_confirmation_admin_facilitator_path(pending)
    assert_redirected_to root_path
  end
end
