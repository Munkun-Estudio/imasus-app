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
#   @return [String] "draft" or "published"
# @!attribute [rw] slug
#   @return [String, nil] URL slug assigned on first publish; never rewritten
# @!attribute [rw] publication_updated_at
#   @return [ActiveSupport::TimeWithZone, nil] timestamp of last publish/republish
class Project < ApplicationRecord
  ALLOWED_LANGUAGES = %w[en es it el].freeze
  ALLOWED_STATUSES  = %w[draft published].freeze
  HERO_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg].freeze
  HERO_IMAGE_MAX_SIZE = 20.megabytes
  SLUG_MAX_LENGTH   = 100

  # @!scope class
  # @!method published
  # @return [ActiveRecord::Relation] projects with status "published"
  scope :published, -> { where(status: "published") }

  # @!method active
  # @return [ActiveRecord::Relation] projects that have not been
  #   soft-disabled by a facilitator or admin (spec 13).
  scope :active,    -> { where(disabled_at: nil) }

  belongs_to :workshop
  belongs_to :challenge, optional: true
  belongs_to :disabled_by, class_name: "User", optional: true

  has_many :memberships, class_name: "ProjectMembership", dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :log_entries, dependent: :destroy

  has_rich_text :process_summary
  has_one_attached :hero_image

  after_initialize :set_defaults, if: :new_record?
  before_validation :assign_slug, if: -> { status == "published" && slug.blank? }

  validates :title,    presence: true
  validates :language, presence: true, inclusion: { in: ALLOWED_LANGUAGES }
  validates :status,   presence: true, inclusion: { in: ALLOWED_STATUSES }

  validate :publication_requirements, if: -> { status == "published" }

  # @return [Boolean] true when +user+ may read this project
  def visible_to?(user)
    return false if user.nil?
    return true  if user.admin? || user.facilitator?

    members.include?(user)
  end

  # @return [Boolean] true when +user+ may write this project. Disabled
  #   projects are not editable by anyone — re-enable first to edit.
  def editable_by?(user)
    return false if user.nil?
    return false if disabled?
    return true  if user.admin?

    members.include?(user)
  end

  # @return [Boolean] true when this project has been soft-disabled by a
  #   facilitator or admin. See {#disable!} and {#enable!}.
  def disabled?
    disabled_at.present?
  end

  # Soft-disable the project. Idempotent: a project that is already
  # disabled keeps its original `disabled_at` and `disabled_by`. Re-enable
  # via {#enable!}.
  #
  # @param by [User] the moderator performing the action
  # @return [void]
  def disable!(by:)
    return if disabled?

    update!(disabled_at: Time.current, disabled_by: by)
  end

  # Clear the disabled state, restoring normal visibility and edit access.
  #
  # @return [void]
  def enable!
    return unless disabled?

    update!(disabled_at: nil, disabled_by: nil)
  end

  # @return [Boolean] true when the project status is "published".
  def published?
    status == "published"
  end

  # @return [Boolean] true when +user+ may publish this draft project.
  #   Members and admins can publish; facilitators cannot.
  def publishable_by?(user)
    !published? && editable_by?(user)
  end

  # @return [Boolean] true when +user+ may re-publish (edit) this published
  #   project. Members and admins qualify; facilitators do not.
  def republishable_by?(user)
    published? && editable_by?(user)
  end

  private

  def set_defaults
    self.status   ||= "draft"
    self.language ||= workshop&.communication_locale
  end

  def publication_requirements
    if hero_image.attached?
      unless HERO_IMAGE_CONTENT_TYPES.include?(hero_image.blob.content_type)
        errors.add(:hero_image, "must be a JPEG or PNG image")
      end

      if hero_image.blob.byte_size > HERO_IMAGE_MAX_SIZE
        errors.add(:hero_image, "must be smaller than #{HERO_IMAGE_MAX_SIZE / 1.megabyte} MB")
      end
    else
      errors.add(:hero_image, :blank)
    end

    errors.add(:process_summary, :blank) if process_summary.blank?
  end

  def assign_slug
    base = title.to_s.parameterize
    base = base[0, SLUG_MAX_LENGTH]
    return if base.blank?

    candidate = base
    suffix = 2
    scope = self.class.where.not(id: id)
    while scope.exists?(slug: candidate)
      candidate = "#{base[0, SLUG_MAX_LENGTH - "-#{suffix}".length]}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end
end
