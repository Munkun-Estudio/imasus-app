require "test_helper"

class Admin::WorkshopEmailsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def setup
    @password = "correct horse battery staple"
    @workshop = Workshop.create!(
      slug: "spain",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @admin = User.create!(name: "Admin", email: "admin-emails@example.com", password: @password, role: :admin)
    @facilitator = User.create!(name: "Fac", email: "fac-emails@example.com", password: @password, role: :facilitator)
    @participant = User.create!(name: "Part", email: "part-emails@example.com", password: @password, role: :participant)

    WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    WorkshopParticipation.create!(user: @participant, workshop: @workshop)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  def draft_params(audience: "both")
    {
      workshop_email: {
        audience: audience,
        subject: "Follow-up from Zaragoza",
        body: "<div>Thanks for joining the workshop.</div><ul><li>Slides tomorrow</li></ul>"
      }
    }
  end

  def pdf_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample-document.pdf"),
      "application/pdf"
    )
  end

  test "unauthenticated users are redirected to login" do
    get admin_workshop_emails_path(@workshop)
    assert_redirected_to new_session_path
  end

  test "non-admin users are denied access" do
    sign_in(@facilitator)
    get admin_workshop_emails_path(@workshop)
    assert_redirected_to root_path
  end

  test "admin can view the history index" do
    WorkshopEmailBroadcast.create!(
      sender: @admin,
      workshop: @workshop,
      audience: "participants",
      subject: "Past update",
      body_html: "<div>Body</div>",
      body_text: "Body",
      recipient_count: 1,
      sent_at: Time.current
    )

    sign_in(@admin)
    get admin_workshop_emails_path(@workshop)

    assert_response :success
    assert_select "h1", text: /Emails/
    assert_select "h2", text: "Past update"
  end

  test "new composer embeds authenticity tokens in rendered forms" do
    sign_in(@admin)
    get new_admin_workshop_email_path(@workshop)

    assert_response :success
    assert_select "input[name=?][type=?]", "authenticity_token", "hidden", minimum: 1
  end

  test "preview renders recipient count without persisting a broadcast" do
    sign_in(@admin)

    assert_no_difference -> { WorkshopEmailBroadcast.count } do
      post admin_workshop_emails_path(@workshop), params: draft_params
    end

    assert_response :success
    assert_select "h2", text: "Follow-up from Zaragoza"
    assert_select "span", text: /2 recipients/
    assert_select "input[type=submit][value=?]", I18n.t("admin.workshop_emails.new.confirm_send")
    assert_select "input[type=submit][value=?]", I18n.t("admin.workshop_emails.new.back_to_edit")
    assert_select "select[name=?]", "workshop_email[audience]", count: 0
  end

  test "preview preserves an uploaded pdf attachment" do
    sign_in(@admin)

    post admin_workshop_emails_path(@workshop),
         params: draft_params.merge(workshop_email: draft_params.fetch(:workshop_email).merge(pdf_attachment: pdf_upload))

    assert_response :success
    assert_select "p", text: "sample-document.pdf"
    assert_select "input[name=?][type=?]", "workshop_email[pdf_attachment_signed_id]", "hidden", count: 2
  end

  test "back to edit returns from preview to the composer without sending" do
    sign_in(@admin)

    assert_no_difference -> { WorkshopEmailBroadcast.count } do
      post admin_workshop_emails_path(@workshop),
           params: draft_params.merge(edit_mode: "1")
    end

    assert_response :success
    assert_select "select[name=?]", "workshop_email[audience]", count: 1
    assert_select "input[type=submit][value=?]", I18n.t("admin.workshop_emails.new.confirm_send"), count: 0
  end

  test "send test emails only the current admin and does not persist" do
    sign_in(@admin)

    assert_no_difference -> { WorkshopEmailBroadcast.count } do
      assert_emails 1 do
        post send_test_admin_workshop_emails_path(@workshop),
             params: draft_params(audience: nil).merge(workshop_email: draft_params(audience: nil).fetch(:workshop_email).merge(pdf_attachment: pdf_upload))
      end
    end

    assert_redirected_to %r{/admin/workshops/spain/emails/new}
    assert_match "workshop_email%5Bpdf_attachment_signed_id%5D=", response.location
    follow_redirect!
    assert_response :success
    assert_match @admin.email, flash[:notice]
    assert_select "select[name=?]", "workshop_email[audience]", count: 1
    assert_select "input[type=submit][value=?]", I18n.t("admin.workshop_emails.new.confirm_send"), count: 0
    assert_select "input[name=?][type=?]", "workshop_email[pdf_attachment_signed_id]", "hidden", count: 1
    assert_equal 1, ActionMailer::Base.deliveries.last.attachments.count
    assert_equal "sample-document.pdf", ActionMailer::Base.deliveries.last.attachments.first.filename.to_s
  end

  test "confirmed send persists the broadcast and emails every selected recipient" do
    sign_in(@admin)

    assert_difference -> { WorkshopEmailBroadcast.count }, 1 do
      assert_emails 2 do
        post admin_workshop_emails_path(@workshop),
             params: draft_params.merge(confirm_send: "1", workshop_email: draft_params.fetch(:workshop_email).merge(pdf_attachment: pdf_upload))
      end
    end

    broadcast = WorkshopEmailBroadcast.order(:created_at).last
    assert_equal @admin, broadcast.sender
    assert_equal @workshop, broadcast.workshop
    assert_equal "both", broadcast.audience
    assert_equal 2, broadcast.recipient_count
    assert broadcast.pdf_attachment.attached?
    assert_redirected_to admin_workshop_emails_path(@workshop)
  end

  test "confirmed send is blocked when the selected audience is empty" do
    WorkshopParticipation.where(user: @facilitator, workshop: @workshop).delete_all
    sign_in(@admin)

    assert_no_difference -> { WorkshopEmailBroadcast.count } do
      assert_no_emails do
        post admin_workshop_emails_path(@workshop),
             params: draft_params(audience: "facilitators").merge(confirm_send: "1")
      end
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]"
  end
end
