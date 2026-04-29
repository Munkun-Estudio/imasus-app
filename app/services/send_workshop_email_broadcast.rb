class SendWorkshopEmailBroadcast
  def self.call(draft:)
    new(draft:).call
  end

  def initialize(draft:)
    @draft = draft
  end

  def call
    raise ArgumentError, "draft must be valid for delivery" unless draft.valid?(:delivery)

    broadcast = WorkshopEmailBroadcast.create!(
      sender: draft.sender,
      workshop: draft.workshop,
      audience: draft.audience,
      subject: draft.normalized_subject,
      body_html: draft.normalized_html,
      body_text: draft.normalized_text,
      recipient_count: draft.recipient_count,
      sent_at: Time.current
    )

    draft.recipients.find_each do |recipient|
      WorkshopEmailBroadcastMailer.broadcast(broadcast, recipient).deliver_later
    end

    broadcast
  end

  private

  attr_reader :draft
end
