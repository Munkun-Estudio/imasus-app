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

Tag.seed_from_yaml!
puts "Seeded #{Tag.count} material tags."

Material.seed_from_yaml!
puts "Seeded #{Material.count} materials."
