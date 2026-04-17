namespace :dev do
  desc "Seed a pending facilitator invitation for local testing of the admin flow"
  task seed_facilitator: :environment do
    abort "Refusing to run outside development/test" unless Rails.env.development? || Rails.env.test?

    email = ENV.fetch("FACILITATOR_EMAIL", "facilitator@example.com")
    name  = ENV.fetch("FACILITATOR_NAME",  "Test Facilitator")

    user = User.find_or_initialize_by(email: email.downcase)
    user.name = name
    user.role = :facilitator
    user.save!
    user.generate_invitation_token!

    puts "Seeded facilitator: #{user.email}"
    puts "Invitation URL: http://localhost:3000/facilitator_invitations/#{user.invitation_token}/edit"
  end
end
