class WorkshopEmailDraft
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :audience, :string
  attribute :subject, :string
  attribute :body, :string

  attr_accessor :workshop, :sender

  validates :workshop, :sender, presence: true
  validates :audience, inclusion: { in: WorkshopEmailBroadcast::AUDIENCES }
  validates :subject, presence: true
  validate :body_present
  validate :sender_is_admin
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
end
