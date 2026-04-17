# A physical workshop (Greece, Italy, or Spain) that participants are invited
# to. This minimal definition exists to support the authentication spec's
# participant invitation flow. Spec 9 (`workshops`) will add dates, agenda,
# partner, and the full public-facing detail.
class Workshop < ApplicationRecord
  has_many :participations, class_name: "WorkshopParticipation", dependent: :destroy
  has_many :participants,   through: :participations, source: :user

  validates :title,    presence: true
  validates :location, presence: true
end
