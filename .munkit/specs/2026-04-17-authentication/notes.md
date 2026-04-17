# Notes: 2026-04-17-authentication

## Implementation decisions

- **`letter_opener`** (not `letter_opener_web`) added to the `:development`
  group in `Gemfile`. Opens a browser tab on every delivery, simpler for
  solo dev use.
- **Seeds**: three workshops (Greece/Italy/Spain) live directly in
  `db/seeds.rb` alongside the admin bootstrap. Admin credentials come from
  env vars (`IMASUS_ADMIN_EMAIL`, `IMASUS_ADMIN_NAME`,
  `IMASUS_ADMIN_PASSWORD`); in development a `changeme-dev` fallback is
  used if the password is unset.
- **`has_secure_password`** in Rails 8 defines a `password_reset_token`
  signed-token helper that shadows our DB column. We pass
  `reset_token: false` to keep control of the column and manage the token
  ourselves, matching the invitation token pattern.
- **Session fixation**: `sign_in_as` calls `reset_session` before setting
  `session[:user_id]`. `SessionsController#create` captures
  `session[:return_to]` into a local before calling `sign_in_as` so the
  post-login redirect target survives the reset.
- **User enumeration**: both `sessions#create` failure and
  `password_resets#create` return generic messages regardless of whether
  the email exists.
- **Password validations**: `has_secure_password validations: false` skips
  the default length/confirmation checks. We re-add `length: { minimum: 8 }`
  and `confirmation: true` gated by `password.present?` so invitation
  records (no password yet) remain valid and confirmation is still
  enforced when a password is set.
- **Terminology**: "participant" is used throughout (model, role enum,
  routes, controllers, views, docs). Workshops target students *and* young
  professionals, so "student" is avoided.
- **Invitation acceptance URL** uses a query-string `?token=…` parameter
  rather than a path segment.

## Security hardening applied after self-review

- Login timing equalised with a dummy BCrypt compare when the email is
  unknown or the user has no `password_digest`, so unactivated accounts
  cannot be detected by response latency.
- `password_resets#update` calls `reset_session` after a successful reset
  so concurrent sessions (e.g. an attacker holding a stolen cookie) are
  invalidated when the user resets their password.
- `participant_invitations#update` redirects using the *participation*
  created_at (the join row created at invite time), not the workshop's
  own created_at, so a participant who was added to an older workshop
  later still lands on the one they were just invited to.
- Invitation tokens are now generated and persisted in a single `User`
  insert (previously a two-step `create!` then `update!`) — no orphaned
  token-less users on partial failure.

## Follow-ups (not in this spec)

- **Token-at-rest hashing**: currently `invitation_token` and
  `password_reset_token` are stored as raw URL-safe strings. A future
  hardening pass should store `Digest::SHA256` of the token and compare
  digests, so a DB-only leak does not yield valid login links.
- **Rate limiting** on `POST /session` and `POST /password_reset` using
  Rails 8's built-in `rate_limit`.
- **Session invalidation on password change** from within the
  authenticated app (not just the reset flow).
- Sidebar navigation for signed-in users (Log in / Log out, Admin link).
- Spanish / Italian / Greek translations for the new auth strings — the
  English keys are canonical in `config/locales/en.yml`; other locales
  currently fall back to the `default:` values.
- A `rails dev:seed_facilitator` task for quick local testing of the
  facilitator invitation flow end-to-end.
- Extract `InviteFacilitator` service to mirror
  `InviteParticipantsToWorkshop`, keeping controllers thin.
- Extract a `TokenAuthenticatable` concern shared by the three
  token-loading controllers.
- Notify existing users when they are linked to a new workshop via the
  bulk-invite flow (currently silent).
