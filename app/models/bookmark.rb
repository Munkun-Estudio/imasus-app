class Bookmark < ApplicationRecord
  BOOKMARKABLE_TYPES = %w[Material GlossaryTerm TrainingModule Challenge].freeze

  belongs_to :user

  validates :bookmarkable_type, presence: true, inclusion: { in: BOOKMARKABLE_TYPES }
  validates :resource_key, presence: true,
                           uniqueness: { scope: %i[user_id bookmarkable_type] }
  validates :label, presence: true
  validates :url,   presence: true

  scope :by_type, ->(type) { where(bookmarkable_type: type) }
  scope :recent,  -> { order(created_at: :desc) }
end
