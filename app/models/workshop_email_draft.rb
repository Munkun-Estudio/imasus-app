class WorkshopEmailDraft
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_PDF_ATTACHMENT_SIZE = 10.megabytes

  attribute :audience, :string
  attribute :subject, :string
  attribute :body, :string
  attribute :pdf_attachment_signed_id, :string

  attr_accessor :workshop, :sender, :pdf_attachment_blob

  validates :workshop, :sender, presence: true
  validates :subject, presence: true
  validate :body_present
  validate :sender_is_admin
  validate :pdf_attachment_is_resolved
  validate :pdf_attachment_is_pdf
  validate :pdf_attachment_size_within_limit
  validate :audience_valid_for_delivery, on: :delivery
  validate :recipients_present, on: :delivery

  def recipients
    return User.none if workshop.blank? || audience.blank?

    scope = workshop.participants.where.not(email: [ nil, "" ]).distinct

    case audience
    when "participants"
      scope.participant
    when "facilitators"
      scope.facilitator
    when "both"
      scope.where(role: [ User.roles[:participant], User.roles[:facilitator] ])
    else
      User.none
    end
  end

  def recipient_count
    recipients.count
  end

  def normalized_subject
    subject.to_s.strip
  end

  def normalized_html
    @normalized_html ||= begin
      html = ActionText::Content.new(body.to_s).to_rendered_html_with_layout
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)

      fragment.css("action-text-attachment").each do |node|
        node.replace(node.children)
      end

      fragment.xpath(".//comment()").remove
      fragment.to_html
    end
  end

  def normalized_text
    @normalized_text ||= ActionText::Content.new(body.to_s).to_plain_text.to_s.strip
  end

  def audience_label
    I18n.t("admin.workshop_emails.audiences.#{audience}",
           default: audience.to_s.humanize)
  end

  def pdf_attachment?
    pdf_attachment_blob.present?
  end

  def pdf_attachment_filename
    pdf_attachment_blob&.filename&.to_s
  end

  def pdf_attachment_byte_size
    pdf_attachment_blob&.byte_size.to_i
  end

  private

  def body_present
    return if normalized_text.present?

    errors.add(:body, :blank)
  end

  def sender_is_admin
    return if sender&.admin?

    errors.add(:sender, :invalid)
  end

  def recipients_present
    return if recipient_count.positive?

    errors.add(:base, I18n.t("admin.workshop_emails.errors.empty_audience",
                             default: "This workshop does not have any recipients in the selected audience."))
  end

  def audience_valid_for_delivery
    return if audience.in?(WorkshopEmailBroadcast::AUDIENCES)

    errors.add(:audience, :inclusion)
  end

  def pdf_attachment_is_resolved
    return if pdf_attachment_signed_id.blank? || pdf_attachment_blob.present?

    errors.add(:pdf_attachment, I18n.t("admin.workshop_emails.errors.invalid_attachment",
                                       default: "The attached PDF could not be loaded. Please upload it again."))
  end

  def pdf_attachment_is_pdf
    return unless pdf_attachment?
    return if pdf_attachment_blob.content_type == "application/pdf"

    errors.add(:pdf_attachment, I18n.t("admin.workshop_emails.errors.attachment_must_be_pdf",
                                       default: "Attach a PDF file."))
  end

  def pdf_attachment_size_within_limit
    return unless pdf_attachment?
    return if pdf_attachment_blob.byte_size <= MAX_PDF_ATTACHMENT_SIZE

    errors.add(:pdf_attachment, I18n.t("admin.workshop_emails.errors.attachment_too_large",
                                       default: "The PDF must be 10 MB or smaller."))
  end
end
