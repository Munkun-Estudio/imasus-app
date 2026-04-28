# Idempotent, production-safe seed data for the IMASUS app.
#
# By default, content seed loaders create missing records and fill blank fields
# without overwriting edits made in production. To intentionally refresh
# repository-backed content from YAML, run:
#
#   SEED_OVERWRITE_CONTENT=1 bin/rails db:seed
#
# or use one of the more specific flags documented below.
#
# The admin user is read from environment variables so credentials never land
# in the repository. In development these can be set via `.env` or exported
# before running `bin/rails db:seed`. In production they come from the host.

overwrite_admin = SeedPolicy.overwrite?(:admin)
admin_email = ENV.fetch("IMASUS_ADMIN_EMAIL", "admin@imasus.local")
admin_name  = ENV.fetch("IMASUS_ADMIN_NAME", "IMASUS Admin")
admin_password = ENV["IMASUS_ADMIN_PASSWORD"].presence ||
                 (Rails.env.development? ? "changeme-dev" : nil)

if admin_password.nil?
  warn "Skipping admin seed: set IMASUS_ADMIN_PASSWORD to create the admin user."
else
  admin = User.find_or_initialize_by(email: admin_email.downcase)
  if admin.new_record? || overwrite_admin
    admin.name = admin_name
    admin.role = :admin
    admin.password = admin_password
    admin.password_confirmation = admin_password
  else
    admin.name = SeedPolicy.value(admin.name, admin_name, overwrite: overwrite_admin)
  end
  admin.invitation_accepted_at ||= Time.current
  admin.save!
  puts "Seeded admin user: #{admin.email}#{overwrite_admin ? ' (overwrite)' : ''}"
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

# Use `bin/rails db:seed:refresh_content` or one of these flags when the
# repository YAML is intentionally the source of truth for existing rows:
#
#   SEED_OVERWRITE_CONTENT=1  # all content loaders
#   SEED_WORKSHOPS=overwrite
#   SEED_GLOSSARY_TERMS=overwrite
#   SEED_CHALLENGES=overwrite
#   SEED_TAGS=overwrite
#   SEED_MATERIALS=overwrite
#   SEED_ADMIN=overwrite

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
