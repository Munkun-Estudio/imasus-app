class Bookmark < ApplicationRecord
  belongs_to :user

  validates :bookmarkable_type,
            presence: true,
            inclusion: { in: ->(_bookmark) { supported_bookmarkable_types } }
  validates :resource_key, presence: true,
                           uniqueness: { scope: %i[user_id bookmarkable_type] }
  validates :label, presence: true
  validates :url,   presence: true

  scope :by_type, ->(type) { where(bookmarkable_type: type) }
  scope :recent,  -> { order(created_at: :desc) }

  def self.supported_bookmarkable_types
    ResourceModuleRegistry.current.all.flat_map(&:bookmark_types)
  end
end
