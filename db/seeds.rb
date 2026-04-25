# Idempotent seed data for the IMASUS app.
#
# The admin user is read from environment variables so credentials never land
# in the repository. In development these can be set via `.env` or exported
# before running `bin/rails db:seed`. In production they come from the host.

admin_email = ENV.fetch("IMASUS_ADMIN_EMAIL", "admin@imasus.local")
admin_name  = ENV.fetch("IMASUS_ADMIN_NAME", "IMASUS Admin")
admin_password = ENV["IMASUS_ADMIN_PASSWORD"].presence ||
                 (Rails.env.development? ? "changeme-dev" : nil)

if admin_password.nil?
  warn "Skipping admin seed: set IMASUS_ADMIN_PASSWORD to create the admin user."
else
  admin = User.find_or_initialize_by(email: admin_email.downcase)
  admin.name ||= admin_name
  admin.role = :admin
  admin.password = admin_password
  admin.password_confirmation = admin_password
  admin.invitation_accepted_at ||= Time.current
  admin.save!
  puts "Seeded admin user: #{admin.email}"
end

Workshop.seed_from_yaml!
puts "Seeded #{Workshop.count} workshops."

GlossaryTerm.seed_from_yaml!
puts "Seeded #{GlossaryTerm.count} glossary terms."

Challenge.seed_from_yaml!
puts "Seeded #{Challenge.count} challenges."

Tag.seed_from_yaml!
puts "Seeded #{Tag.count} material tags."

Material.seed_from_yaml!
puts "Seeded #{Material.count} materials."

# Development-only demo users.
#
# Production seeds intentionally only create the admin; facilitators and
# participants land via the invitation flow. In development we want a
# faster path to log in as each role to manually QA role-aware surfaces
# (the home variants, the user menu, /settings, etc.).
#
# Both demo users share the same dev password as the admin (`changeme-dev`)
# and re-applying the seed is idempotent: existing records are updated in
# place, and re-running keeps passwords + workshop attachment in sync.
if Rails.env.development?
  workshop = Workshop.find_by(slug: "spain")

  if workshop
    demo_password = "changeme-dev"

    facilitator = User.find_or_initialize_by(email: "fac@imasus.local")
    facilitator.assign_attributes(
      name: "Elena",
      role: :facilitator,
      password: demo_password,
      password_confirmation: demo_password
    )
    facilitator.invitation_accepted_at ||= Time.current
    facilitator.save!
    WorkshopParticipation.find_or_create_by!(user: facilitator, workshop: workshop)

    participant = User.find_or_initialize_by(email: "part@imasus.local")
    participant.assign_attributes(
      name: "Maria",
      institution: "Demo Institute",
      role: :participant,
      password: demo_password,
      password_confirmation: demo_password
    )
    participant.invitation_accepted_at ||= Time.current
    participant.save!
    WorkshopParticipation.find_or_create_by!(user: participant, workshop: workshop)

    puts "Seeded demo users: #{facilitator.email} (facilitator), #{participant.email} (participant)"
  else
    warn "Skipping demo users: no 'spain' workshop seeded yet."
  end
end
