# @!attribute [rw] workshop
#   @return [Workshop]
# @!attribute [rw] challenge
#   @return [Challenge, nil]
# @!attribute [rw] title
#   @return [String]
# @!attribute [rw] description
#   @return [String, nil]
# @!attribute [rw] language
#   @return [String] one of %w[en es it el]
# @!attribute [rw] status
#   @return [String] "draft" (further values arrive in spec 12)
class Project < ApplicationRecord
  ALLOWED_LANGUAGES = %w[en es it el].freeze
  ALLOWED_STATUSES  = %w[draft].freeze

  belongs_to :workshop
  belongs_to :challenge, optional: true

  has_many :memberships, class_name: "ProjectMembership", dependent: :destroy
  has_many :members, through: :memberships, source: :user

  after_initialize :set_defaults, if: :new_record?

  validates :title,    presence: true
  validates :language, presence: true, inclusion: { in: ALLOWED_LANGUAGES }
  validates :status,   presence: true, inclusion: { in: ALLOWED_STATUSES }

  # @return [Boolean] true when +user+ may read this project
  def visible_to?(user)
    return false if user.nil?
    return true  if user.admin? || user.facilitator?

    members.include?(user)
  end

  # @return [Boolean] true when +user+ may write this project
  def editable_by?(user)
    return false if user.nil?
    return true  if user.admin?

    members.include?(user)
  end

  private

  def set_defaults
    self.status   ||= "draft"
    self.language ||= workshop&.communication_locale
  end
end
