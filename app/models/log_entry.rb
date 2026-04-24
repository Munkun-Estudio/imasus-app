# A single timestamped entry in a {Project}'s process log.
#
# Entries are append-only (no update action). The author is set at
# create time and never changed. Media attachments are validated for
# count, type, and size before saving.
#
# @!attribute project
#   @return [Project]
# @!attribute author
#   @return [User] the member who created this entry
# @!attribute body
#   @return [ActionText::RichText]
# @!attribute created_at
#   @return [Time] displayed as the entry timestamp
class LogEntry < ApplicationRecord
  belongs_to :project
  belongs_to :author, class_name: "User"

  has_rich_text :body
  has_many_attached :media

  validates :body, presence: true
  validate :media_count_within_limit
  validate :media_types_allowed

  default_scope { order(created_at: :desc) }

  ALLOWED_MEDIA_TYPES = %w[image/jpeg image/png image/webp video/mp4 video/quicktime].freeze
  MAX_MEDIA_COUNT = 10
  MAX_MEDIA_SIZE  = 50.megabytes

  private

  def media_count_within_limit
    return unless media.attached?

    if media.count > MAX_MEDIA_COUNT
      errors.add(:media, :too_many, count: MAX_MEDIA_COUNT)
    end
  end

  def media_types_allowed
    return unless media.attached?

    media.each do |attachment|
      next unless attachment.blob.present?

      unless ALLOWED_MEDIA_TYPES.include?(attachment.content_type)
        errors.add(:media, :invalid_type, filename: attachment.filename)
      end

      if attachment.byte_size > MAX_MEDIA_SIZE
        errors.add(:media, :too_large, filename: attachment.filename)
      end
    end
  end
end
