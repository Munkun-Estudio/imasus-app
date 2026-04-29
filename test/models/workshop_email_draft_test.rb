require "test_helper"

class WorkshopEmailDraftTest < ActiveSupport::TestCase
  def setup
    @workshop = Workshop.create!(
      slug: "spain",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @admin = User.create!(name: "Admin", email: "admin-draft@example.com", role: :admin)
    @facilitator = User.create!(name: "Fac", email: "fac-draft@example.com", role: :facilitator)
    @participant = User.create!(name: "Part", email: "part-draft@example.com", role: :participant)
    WorkshopParticipation.create!(user: @facilitator, workshop: @workshop)
    WorkshopParticipation.create!(user: @participant, workshop: @workshop)
  end

  test "recipients include participants and facilitators for audience both" do
    draft = WorkshopEmailDraft.new(
      workshop: @workshop,
      sender: @admin,
      audience: "both",
      subject: "Follow-up",
      body: "<div>Hello team</div>"
    )

    assert draft.valid?
    assert_equal [ @facilitator, @participant ].sort_by(&:email), draft.recipients.to_a.sort_by(&:email)
    assert_equal "Hello team", draft.normalized_text
  end

  test "delivery validation requires at least one recipient in the selected audience" do
    WorkshopParticipation.where(user: @facilitator, workshop: @workshop).delete_all

    draft = WorkshopEmailDraft.new(
      workshop: @workshop,
      sender: @admin,
      audience: "facilitators",
      subject: "Follow-up",
      body: "<div>Hello team</div>"
    )

    assert_not draft.valid?(:delivery)
    assert_includes draft.errors.full_messages, I18n.t("admin.workshop_emails.errors.empty_audience")
  end

  test "test-send validation does not require an audience" do
    draft = WorkshopEmailDraft.new(
      workshop: @workshop,
      sender: @admin,
      subject: "Follow-up",
      body: "<div>Hello team</div>"
    )

    assert draft.valid?
  end

  test "normalized html renders attached images to real img tags" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )

    draft = WorkshopEmailDraft.new(
      workshop: @workshop,
      sender: @admin,
      audience: "participants",
      subject: "Follow-up",
      body: %(<div>Hello</div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
    )

    assert draft.valid?
    assert_includes draft.normalized_html, "<img"
    assert_includes draft.normalized_html, "sample-image.png"
    assert_not_includes draft.normalized_html, "<action-text-attachment"
  end

  test "optional pdf attachment is accepted when it is a pdf under the size limit" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("test/fixtures/files/sample-document.pdf").open,
      filename: "sample-document.pdf",
      content_type: "application/pdf"
    )

    draft = WorkshopEmailDraft.new(
      workshop: @workshop,
      sender: @admin,
      audience: "participants",
      subject: "Follow-up",
      body: "<div>Hello team</div>",
      pdf_attachment_signed_id: blob.signed_id,
      pdf_attachment_blob: blob
    )

    assert draft.valid?(:delivery)
    assert_equal "sample-document.pdf", draft.pdf_attachment_filename
  end

  test "pdf attachment validation rejects non-pdf blobs" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("not a pdf"),
      filename: "notes.txt",
      content_type: "text/plain"
    )

    draft = WorkshopEmailDraft.new(
      workshop: @workshop,
      sender: @admin,
      audience: "participants",
      subject: "Follow-up",
      body: "<div>Hello team</div>",
      pdf_attachment_signed_id: blob.signed_id,
      pdf_attachment_blob: blob
    )

    assert_not draft.valid?
    assert_includes draft.errors[:pdf_attachment], I18n.t("admin.workshop_emails.errors.attachment_must_be_pdf")
  end
end
