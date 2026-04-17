# Application user. Represents one of three roles — admin, facilitator, or
# participant — and owns the invitation and password-reset token lifecycle.
#
# Participants (students and young professionals) register via a facilitator
# invitation; facilitators register via an admin invitation; the admin is
# seeded. A user exists before it has a password: invitation flows create the
# record first and set the password when the token is accepted.
#
# @!attribute [rw] email
#   @return [String] Normalised to lowercase before validation.
# @!attribute [rw] role
#   @return [String] One of "admin", "facilitator", "participant".
# @!attribute [rw] invitation_token
#   @return [String, nil] One-time URL-safe token; cleared on acceptance.
# @!attribute [rw] password_reset_token
#   @return [String, nil] One-time URL-safe token; cleared after reset.
class User < ApplicationRecord
  # Expiry windows for invitation tokens, keyed by role. Admin is not a real
  # invitee (it is seeded), but is included for completeness.
  INVITATION_EXPIRY = {
    "admin"       => 7.days,
    "facilitator" => 7.days,
    "participant" => 14.days
  }.freeze

  # Password-reset tokens are short-lived to limit exposure.
  PASSWORD_RESET_EXPIRY = 2.hours

  # `reset_token: false` disables the Rails 8 signed-token helper, which would
  # otherwise shadow our `password_reset_token` column with a signed token
  # generator. We manage the token ourselves for consistency with invitations.
  has_secure_password validations: false, reset_token: false

  has_many :workshop_participations, dependent: :destroy
  has_many :workshops, through: :workshop_participations

  enum :role, { admin: 0, facilitator: 1, participant: 2 }, default: :participant

  before_validation :normalise_email

  validates :name,  presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role,  presence: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :password, confirmation: true, if: -> { password.present? }

  # Generates a fresh invitation token and persists it with the sent-at
  # timestamp. The caller is responsible for sending the corresponding mailer.
  #
  # @return [void]
  # @raise [ActiveRecord::RecordInvalid] if validations fail on persistence
  # @example
  #   user.generate_invitation_token!
  #   FacilitatorInvitationMailer.invite(user, user.invitation_token).deliver_later
  def generate_invitation_token!
    update!(
      invitation_token:   SecureRandom.urlsafe_base64(32),
      invitation_sent_at: Time.current
    )
  end

  # @return [Boolean] true when the invitation window for the user's role has
  #   elapsed since `invitation_sent_at`. Returns false if no invitation was
  #   ever sent.
  def invitation_expired?
    return false if invitation_sent_at.nil?

    window = INVITATION_EXPIRY.fetch(role, INVITATION_EXPIRY["participant"])
    invitation_sent_at < window.ago
  end

  # Marks the invitation as accepted and clears the one-time token so the
  # acceptance link cannot be reused.
  #
  # @return [void]
  # @raise [ActiveRecord::RecordInvalid] if validations fail on persistence
  def accept_invitation!
    update!(
      invitation_token:       nil,
      invitation_accepted_at: Time.current
    )
  end

  # Generates a short-lived password-reset token and persists it with the
  # sent-at timestamp.
  #
  # @return [void]
  # @raise [ActiveRecord::RecordInvalid] if validations fail on persistence
  def generate_password_reset_token!
    update!(
      password_reset_token:   SecureRandom.urlsafe_base64(32),
      password_reset_sent_at: Time.current
    )
  end

  # @return [Boolean] true when the password-reset window has elapsed, or when
  #   no reset was ever sent (defensive default).
  def password_reset_expired?
    return true if password_reset_sent_at.nil?

    password_reset_sent_at < PASSWORD_RESET_EXPIRY.ago
  end

  # Clears the password-reset token after a successful reset.
  #
  # @return [void]
  # @raise [ActiveRecord::RecordInvalid] if validations fail on persistence
  def clear_password_reset!
    update!(password_reset_token: nil, password_reset_sent_at: nil)
  end

  private

  def normalise_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
