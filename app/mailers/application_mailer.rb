class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "IMASUS <no-reply@imasus-app.fly.dev>")
  layout "mailer"
end
