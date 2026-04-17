require "test_helper"

class UserTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      name: "Alex Example",
      email: "alex@example.com",
      password: "correct horse battery staple",
      password_confirmation: "correct horse battery staple",
      role: :participant
    }.merge(overrides)
  end

  test "valid with required attributes" do
    user = User.new(valid_attributes)
    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "requires name" do
    user = User.new(valid_attributes(name: nil))
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "requires email" do
    user = User.new(valid_attributes(email: nil))
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires email format" do
    user = User.new(valid_attributes(email: "not-an-email"))
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "email must be unique (case-insensitive)" do
    User.create!(valid_attributes)
    dup = User.new(valid_attributes(email: "ALEX@Example.com"))
    assert_not dup.valid?
    assert_includes dup.errors[:email], "has already been taken"
  end

  test "normalises email to lowercase before save" do
    user = User.create!(valid_attributes(email: "  AleX@Example.COM "))
    assert_equal "alex@example.com", user.reload.email
  end

  test "role defaults to participant" do
    user = User.new(valid_attributes.except(:role))
    assert_equal "participant", user.role
  end

  test "role enum recognises all three values" do
    admin = User.create!(valid_attributes(email: "a@example.com", role: :admin))
    facilitator = User.create!(valid_attributes(email: "f@example.com", role: :facilitator))
    participant = User.create!(valid_attributes(email: "p@example.com", role: :participant))
    assert admin.admin?
    assert facilitator.facilitator?
    assert participant.participant?
  end

  test "has_secure_password stores digest and authenticates" do
    user = User.create!(valid_attributes)
    assert user.password_digest.present?
    assert user.authenticate("correct horse battery staple")
    assert_not user.authenticate("wrong password")
  end

  test "allows creation without password (pre-invitation state)" do
    user = User.new(valid_attributes.except(:password, :password_confirmation))
    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "generate_invitation_token! sets token and timestamp" do
    user = User.create!(valid_attributes.except(:password, :password_confirmation))
    freeze_time do
      user.generate_invitation_token!
      assert user.invitation_token.present?
      assert_equal Time.current, user.invitation_sent_at
    end
  end

  test "invitation token expires after facilitator window (7 days)" do
    user = User.create!(valid_attributes(role: :facilitator).except(:password, :password_confirmation))
    user.update!(invitation_token: "t", invitation_sent_at: 8.days.ago)
    assert user.invitation_expired?
  end

  test "invitation token expires after participant window (14 days)" do
    user = User.create!(valid_attributes(role: :participant).except(:password, :password_confirmation))
    user.update!(invitation_token: "t", invitation_sent_at: 15.days.ago)
    assert user.invitation_expired?
  end

  test "invitation is not expired within its window" do
    user = User.create!(valid_attributes(role: :participant).except(:password, :password_confirmation))
    user.update!(invitation_token: "t", invitation_sent_at: 1.day.ago)
    assert_not user.invitation_expired?
  end

  test "accept_invitation! clears token and records acceptance" do
    user = User.create!(valid_attributes.except(:password, :password_confirmation))
    user.generate_invitation_token!
    freeze_time do
      user.accept_invitation!
      assert_nil user.invitation_token
      assert_equal Time.current, user.invitation_accepted_at
    end
  end

  test "generate_password_reset_token! sets token and timestamp" do
    user = User.create!(valid_attributes)
    freeze_time do
      user.generate_password_reset_token!
      assert user.password_reset_token.present?
      assert_equal Time.current, user.password_reset_sent_at
    end
  end

  test "password reset token expires after 2 hours" do
    user = User.create!(valid_attributes)
    user.update!(password_reset_token: "t", password_reset_sent_at: 3.hours.ago)
    assert user.password_reset_expired?
  end

  test "password reset token is fresh within 2 hours" do
    user = User.create!(valid_attributes)
    user.update!(password_reset_token: "t", password_reset_sent_at: 30.minutes.ago)
    assert_not user.password_reset_expired?
  end

  test "clear_password_reset! removes the token and timestamp" do
    user = User.create!(valid_attributes)
    user.generate_password_reset_token!
    user.clear_password_reset!
    assert_nil user.password_reset_token
    assert_nil user.password_reset_sent_at
  end
end
