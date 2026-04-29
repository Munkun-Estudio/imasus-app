require "test_helper"

class WorkshopEmailBroadcastMailerTest < ActionMailer::TestCase
  test "broadcast renders both html and text parts" do
    workshop = Workshop.create!(
      slug: "spain",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    sender = User.create!(name: "Admin", email: "admin-mailer@example.com", role: :admin)
    recipient = User.create!(name: "Part", email: "part-mailer@example.com", role: :participant)
    broadcast = WorkshopEmailBroadcast.create!(
      sender: sender,
      workshop: workshop,
      audience: "participants",
      subject: "Workshop follow-up",
      body_html: "<div><strong>Thanks</strong> for coming.</div>",
      body_text: "Thanks for coming.",
      recipient_count: 1,
      sent_at: Time.current
    )
    broadcast.pdf_attachment.attach(
      io: Rails.root.join("test/fixtures/files/sample-document.pdf").open,
      filename: "sample-document.pdf",
      content_type: "application/pdf"
    )

    email = WorkshopEmailBroadcastMailer.broadcast(broadcast, recipient)

    assert_equal [ "part-mailer@example.com" ], email.to
    assert_equal "Workshop follow-up", email.subject
    assert_equal 2, email.parts.size
    assert_equal 1, email.attachments.count
    assert_equal "sample-document.pdf", email.attachments.first.filename.to_s
    assert_includes email.html_part.body.to_s, "Thanks"
    assert_includes email.text_part.body.to_s, "Thanks for coming."
    assert_includes email.body.encoded, "Taller IMASUS Espana"
  end
end
