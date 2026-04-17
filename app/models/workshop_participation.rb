# Join model linking a User (typically a participant) to a Workshop. A user
# can belong to multiple workshops; a workshop has many participants.
class WorkshopParticipation < ApplicationRecord
  belongs_to :user
  belongs_to :workshop

  validates :user_id, uniqueness: { scope: :workshop_id }
end
