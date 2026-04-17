# Invites a batch of participants to a workshop from a newline-separated
# block of email addresses. Handles deduplication (case-insensitive, within
# the same request), skips users who already have an account, and only
# emails freshly created users.
#
# @example Invite from a textarea
#   result = InviteParticipantsToWorkshop.call(workshop: ws, emails: params[:emails])
#   result.invited            # => ["alice@example.com"]
#   result.already_registered # => ["bob@example.com"]
#   result.invalid            # => ["not-an-email"]
class InviteParticipantsToWorkshop
  # Tally of outcomes for a batch call.
  # @!attribute invited
  #   @return [Array<String>] emails of newly created & mailed participants
  # @!attribute already_registered
  #   @return [Array<String>] emails of existing users linked without a mail
  # @!attribute invalid
  #   @return [Array<String>] emails that failed format validation
  Result = Struct.new(:invited, :already_registered, :invalid, keyword_init: true)

  # @param workshop [Workshop] target workshop for the participations
  # @param emails [String] newline-separated list of email addresses
  # @return [Result]
  def self.call(workshop:, emails:)
    new(workshop: workshop, emails: emails).call
  end

  # @param workshop [Workshop]
  # @param emails [String]
  def initialize(workshop:, emails:)
    @workshop = workshop
    @emails   = emails.to_s
  end

  # Performs the batch invitation.
  # @return [Result]
  # @raise [ActiveRecord::RecordInvalid] if a User or WorkshopParticipation cannot be persisted
  def call
    invited            = []
    already_registered = []
    invalid            = []

    parsed_emails.each do |email|
      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        invalid << email
        next
      end

      user = User.find_by("LOWER(email) = ?", email)

      if user
        # Only attach existing users who are already participants. Admin and
        # facilitator accounts pasted into the textarea are skipped entirely
        # so role/membership semantics stay clean.
        if user.participant?
          WorkshopParticipation.find_or_create_by!(user: user, workshop: @workshop)
        end
        already_registered << email
      else
        ApplicationRecord.transaction do
          user = User.create!(
            name: email.split("@").first,
            email: email,
            role: :participant,
            invitation_token: SecureRandom.urlsafe_base64(32),
            invitation_sent_at: Time.current
          )
          WorkshopParticipation.create!(user: user, workshop: @workshop)
        end
        ParticipantInvitationMailer.invite(user, user.invitation_token, @workshop).deliver_later
        invited << email
      end
    end

    Result.new(invited: invited, already_registered: already_registered, invalid: invalid)
  end

  private

  def parsed_emails
    @emails.split(/\r?\n/).map { |e| e.strip.downcase }.reject(&:empty?).uniq
  end
end
