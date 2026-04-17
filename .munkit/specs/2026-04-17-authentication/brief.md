# Authentication

## What

Add the full authentication layer using Rails built-ins (`has_secure_password`, cookie-based sessions, `SecureRandom` tokens). Three roles — admin, facilitator, participant — with invitation-only participant registration and transactional emails for invitation, registration confirmation, and password reset.

No third-party auth library. No open self-registration for participants.

## Why

Authentication is the critical-path blocker for every collaborative feature: workshops, projects, process log, publication, and facilitator tools all require a logged-in user with a known role. Nothing in specs 9–14 can be built without it.

## Roles

| Role | Created by | Notes |
|------|-----------|-------|
| admin | Seeded | One admin per environment. Has full access. Creates facilitator accounts. |
| facilitator | admin | Receives email to set password after admin creates their account. Manages workshops and invites participants. |
| participant | self (via invitation) | Registers via token link sent by facilitator. Pre-associated with a workshop. Covers students and young professionals. |

## Acceptance Criteria

### User model

- [ ] `User` model with: `name`, `email` (unique, downcased), `password_digest` (`has_secure_password`), `role` (enum: `admin`, `facilitator`, `participant`), `institution`, `country`, `bio`, `links` (text — open-ended), `invitation_token`, `invitation_sent_at`, `invitation_accepted_at`, `password_reset_token`, `password_reset_sent_at`.
- [ ] Email is normalised to lowercase before save.
- [ ] `role` defaults to `participant`.
- [ ] Model-level validations: presence of name + email + role; format of email; uniqueness of email.

### Sessions (login / logout)

- [ ] `SessionsController` with `new`, `create`, `destroy`.
- [ ] Login form: email + password. On success, store `user_id` in the encrypted session cookie. Redirect to root path (or originally requested URL if stored).
- [ ] On failure, re-render the form with a generic "Invalid email or password" flash — no user enumeration.
- [ ] Logout destroys the session and redirects to login.
- [ ] `ApplicationController` provides `current_user`, `logged_in?`, and `require_login` before-action helpers. `require_login` redirects to login and stores the requested URL in the session.

### Role-based access

- [ ] `require_role(*roles)` helper in `ApplicationController` — redirects with a 403 flash if `current_user.role` is not in the allowed list.
- [ ] Admin-only: facilitator creation routes (`/admin/facilitators`).
- [ ] Facilitator + admin: workshop management, participant invitation.
- [ ] Participant: project and log routes (specs 10–11 will add these; this spec only wires the guard).

### Interface

#### Admin — facilitator management (`/admin/facilitators`)

- [ ] `Admin::FacilitatorsController` with `index`, `new`, `create`.
- [ ] `/admin/facilitators` — lists all facilitators (name, email, invitation status).
- [ ] `/admin/facilitators/new` — form: name + email. Submit sends the invitation email and redirects to the index with a flash.
- [ ] Admin area is protected by `require_role :admin`. No sidebar nav item — reachable via a link in the admin dashboard or directly by URL.

#### Facilitator — participant invitation (within workshop context)

- [ ] `InvitationsController` nested under workshops: `new`, `create`.
- [ ] Invitation UI lives at `/workshops/:workshop_id/invitations/new` — a textarea (one email per line). Workshop is implicit from the URL.
- [ ] On submit: iterate emails, skip existing users, create `User` (role: participant) + `WorkshopParticipation`, send `ParticipantInvitationMailer`. Redirect back to the workshop page with a summary flash: "X invited, Y skipped (already registered)."
- [ ] Link to this page appears on the workshop detail view, visible only to facilitators and admins.

#### Invitation acceptance pages

- [ ] `FacilitatorInvitationsController#edit` / `#update` at `/facilitator_invitations/:token` — form: name (pre-filled), password, password confirmation.
- [ ] `ParticipantInvitationsController#edit` / `#update` at `/participant_invitations/:token` — form: name, institution, country, bio, links, password, password confirmation. Email pre-filled and read-only.
- [ ] Both pages render a clear error when the token is expired, with role-appropriate guidance ("contact the admin" / "contact your facilitator").

#### Routes summary

```ruby
resource  :session,        only: [:new, :create, :destroy]
resource  :password_reset, only: [:new, :create, :edit, :update]

namespace :admin do
  resources :facilitators, only: [:index, :new, :create]
end

resources :workshops, only: [] do
  resources :invitations, only: [:new, :create]
end

resources :facilitator_invitations, only: [] do
  member { get  :edit; patch :update }
end

resources :participant_invitations, only: [] do
  member { get  :edit; patch :update }
end
```

### Facilitator account creation (admin)

- [ ] On creation, `FacilitatorInvitationMailer` sends a secure token link to the facilitator.
- [ ] Token expires after 7 days. Expired-token visit renders a clear error.
- [ ] On successful accept: token cleared, `invitation_accepted_at` set, session started, redirect to root.

### Participant invitation (facilitator)

- [ ] Per email: existing `User` → skip. New → create `User` (role: participant, no password) + `WorkshopParticipation`, send `ParticipantInvitationMailer`.
- [ ] Token expires after 14 days.
- [ ] On successful accept: token cleared, `invitation_accepted_at` set, session started, redirect to the workshop page.

### Password reset

- [ ] "Forgot password?" link on the login page.
- [ ] `PasswordResetsController` with `new`, `create`, `edit`, `update`.
- [ ] `create`: if email matches a user, generate token, set `password_reset_sent_at`, send `PasswordResetMailer`. Always render the same confirmation copy — no user enumeration.
- [ ] `edit`: validate token exists and `password_reset_sent_at` is within 2 hours. Expired → redirect to `new` with flash.
- [ ] `update`: set new password, clear reset token fields.

### Transactional emails

- [ ] Three mailers: `FacilitatorInvitationMailer`, `ParticipantInvitationMailer`, `PasswordResetMailer`.
- [ ] Each has text + HTML views.
- [ ] Development uses `letter_opener` (or `letter_opener_web`) for local preview. No production SMTP config in this spec.
- [ ] Subject lines and body copy go through `t(...)`. en locale required; es/it/el can be stubs.

### Seeds

- [ ] `db/seeds.rb` creates one admin user (credentials from env vars with safe local fallbacks — no hard-coded passwords in source).
- [ ] A `rails dev:seed_facilitator` task creates a sample facilitator for local development without sending real email.

### Tests (Minitest — tests gate implementation)

- [ ] Model: validations, `has_secure_password`, email normalisation, token expiry predicate methods.
- [ ] Controller: login success → session set; login failure → no session, generic flash; logout → session cleared; `require_login` redirect; `require_role` redirect.
- [ ] Facilitator invitation: happy path + expired token.
- [ ] Participant invitation: happy path + expired token + duplicate email skipped.
- [ ] Password reset: no enumeration on create; valid token shows form; expired token redirects; successful reset clears token.
- [ ] Mailers: each renders subject and body with the token URL (no real send).

## Out of Scope

- OAuth / social login.
- Two-factor authentication.
- User profile editing post-registration.
- Email confirmation on registration (invitation token serves this purpose).
- SMTP configuration for production (deployment spec).
- In-app notifications.
- Avatar uploads.

## Dependencies

- Spec 1 (`app-shell-and-navigation`) — layout shell, I18n plumbing.

## Notes

- `WorkshopParticipation` join model is introduced here. The full `Workshop` model lands in spec 9 — for now, seed three known workshop records so the invitation form has real options. Spec 9 will flesh out the model fully.
- `links` on User is a plain text column (one URL per line). Structured parsing is deferred.
- Consider `ActiveSupport::CurrentAttributes` (`Current.user`) for thread-local user access — avoids passing user through method chains across future specs.
