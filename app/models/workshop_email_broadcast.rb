class WorkshopEmailBroadcast < ApplicationRecord
  AUDIENCES = %w[participants facilitators both].freeze

  belongs_to :sender, class_name: "User"
  belongs_to :workshop

  validates :audience, inclusion: { in: AUDIENCES }
  validates :subject, :body_html, :body_text, :sent_at, presence: true
  validates :recipient_count, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(sent_at: :desc, created_at: :desc) }

  def audience_label
    I18n.t("admin.workshop_emails.audiences.#{audience}",
           default: audience.humanize)
  end
end
