# Notes: 2026-05-19-admin-facilitator-management

Scratch space and decision rationale. Brief is the contract; this file
is the journal.

---

## How this spec ended up at this scope

Triggered by a production incident on 2026-05-19: Lauren
(lauren@lottozero.org) could not edit the Italian workshop she was
supposed to facilitate. Diagnosis: admin created the workshop, then
separately invited Lauren via `/admin/facilitators/new`. The invite
flow does **not** create a `WorkshopParticipation`, and the only
auto-attach is on `WorkshopsController#create` for the creator. Net
effect: Lauren's facilitator user existed but had no link to the
workshop, so `Workshop#manageable_by?` returned `false` and the edit
surface was hidden.

Quick fix in production: created the missing
`WorkshopParticipation` manually via Rails console. This spec replaces
that workaround with an admin-self-serviceable surface.

The user also asked for a cleanup path for pending invitations
(typo'd emails, abandoned invites). That's the second piece in the
brief.

This spec is also the natural place to **close the spec-10
deferral** recorded in `DECISIONS.md` 2026-04-23: *"`Project#visible_to?`
grants all facilitators read access to all draft projects until spec
13 adds per-workshop facilitator assignment."* Spec 13 shipped
without that tightening because there was no way to **establish**
per-workshop facilitator assignment in the first place. This spec
provides that path. The tightening of `Project#visible_to?` itself
is deferred to its own follow-up (see brief Out of Scope) — naming
it here so the trail doesn't go cold again.

---

## Decision log

### Facilitator-centric vs workshop-centric admin

- (a) ~~Workshop-side "Manage facilitators" panel on
  `/workshops/:slug/edit` (admin-only).~~ Considered. Symmetrical and
  intuitive at the moment of workshop creation. Rejected as the
  *primary* surface because:
  - The existing entry point on the admin home is "Manage
    facilitators", not "Manage workshops". Reading "who can access
    what" from the person matches the operational mental model.
  - The dataset is small (handful of facilitators, one or two
    workshops each). Facilitator-centric scales fine.
  - Adds a second admin surface to a page (workshop edit) that
    facilitators also use — separation of concerns is cleaner if the
    admin actions live in the admin namespace.
- (b) ✅ **Facilitator-centric on
  `/admin/facilitators/:id`.** Single admin surface, single mental
  model. Workshop-side can be added later if needed.

### `WorkshopParticipation` stays role-agnostic

**Already decided** — see `DECISIONS.md` 2026-04-25 (Spec 13: *"Keep
`WorkshopParticipation` as a single role-agnostic join"*). Not
re-opened here. The investigation findings below confirm every
consumer of `participants` / `participations` still works with the
role-agnostic join + `user.role` check.

### What does "remove a facilitator from a workshop" mean?

Two operations possible:

- (a) ✅ **Unassign from one workshop.** Destroys the
  `WorkshopParticipation`. Facilitator immediately loses management
  on that workshop. Account stays. Any content they authored stays.
- (b) ~~Deactivate the user account globally.~~ Out of scope. No
  `deactivated_at` column exists on `User`; adding one means new
  session plumbing (revoke logins), new login-gate behaviour, new
  display logic. If we need this, it's its own spec.
- (c) ~~Hard-delete the user.~~ Out of scope. Cascades through
  projects, log entries, bookmarks, etc. Needs a real "user
  deletion" design pass (transfer ownership? anonymise? archive?).

The brief only ships (a). For *pending* invitations, hard-delete is
fine because there is no associated content; that's the "revoke
invitation" path.

### Pending-invitation cleanup — hard-delete or expire?

- (a) ~~Wait for the 7-day invitation expiry to silently lapse.~~
  Rejected: the user row stays in the database, still showing on the
  index, no clean signal it's "gone".
- (b) ✅ **Admin-driven hard-delete** of the `User` row for
  `invitation_accepted_at.nil?` users. Cascades through any
  pre-assigned `WorkshopParticipation` via the existing
  `dependent: :destroy` on `User#workshop_participations`. Clean
  state, traceable action.
- (c) ~~Add an "Expired"/"Cancelled" status enum.~~ Overkill. The
  row going away is the cleanest UX.

The original invitation link 404s after the user row is destroyed
because `FacilitatorInvitationsController#set_user_from_token` does
`User.find_by(invitation_token: token)` and treats `nil` as invalid.
Verified in app/controllers/facilitator_invitations_controller.rb:24-33.

### Invite + assign — combined or separate flows?

- ✅ **Combined, with assignment optional.** Add a `workshop_ids`
  multi-select to the existing invite form. Empty = today's
  behaviour. Non-empty = create user and participations in one
  transaction.

This is purely additive; existing tests should pass with no changes.

### Workshop dropdown content — all workshops or "facilitator-eligible"?

- ✅ **All workshops.** Admins can assign to any workshop. There is no
  notion of "this facilitator is restricted to these workshops"
  beyond what assignment itself creates. Filtering would obscure the
  control.

### Workshop assignment uniqueness — guard rails

`WorkshopParticipation` already validates
`uniqueness: { user_id: scoped_to: :workshop_id }`. The controller
uses `find_or_create_by!` to make the create idempotent. Double-submit
or page refresh will not duplicate or error.

---

## Investigation findings (frozen 2026-05-19)

Captured from the pre-spec exploration so the rationale stays with
the brief.

### `WorkshopParticipation` consumers

Every place a `WorkshopParticipation` row gates behaviour:

| File | What it gates |
| --- | --- |
| `app/models/workshop.rb:79-84` | `manageable_by?` — workshop edit/update, participant list, project moderation |
| `app/controllers/projects_controller.rb:19` | Facilitator's projects index filtered to their workshops |
| `app/controllers/projects_controller.rb:102-104` | Facilitator can create projects only in their workshops |
| `app/controllers/project_memberships_controller.rb:7,15` | Eligibility to be added to a project (must be in the workshop) |
| `app/controllers/workshop_participants_controller.rb:15-27` | Listing of who's in a workshop |
| `app/models/workshop_email_draft.rb:27` | Email broadcast recipient filtering by role |
| `app/helpers/workshops_helper.rb:41` | "Attending" badge on workshop show page |
| `app/controllers/participant_invitations_controller.rb:52` | Redirect target for newly-accepted participants |
| `lib/.../invite_participants_to_workshop.rb:56,68` | Creation path for participant invitations |

Implication for the brief: **revoking a facilitator's
`WorkshopParticipation` is intentionally all-or-nothing** — they lose
edit, project moderation, project creation, the participant list, and
email-broadcast eligibility for that workshop in one go. That is
exactly what "unassign" should do. Worth documenting in the show-page
confirm dialog copy.

### Workshop-side facilitator visibility today

None. `app/views/workshops/edit.html.erb` and its `_form` partial
have no facilitator UI. The admin namespace
(`app/controllers/admin/`) only has `facilitators_controller.rb` and
`workshop_emails_controller.rb`. No `admin/workshops/...` namespace.

This confirms the brief: workshop-side management does not exist and
is not silently being relied upon. Adding facilitator-centric admin
in isolation creates no inconsistency.

### User model: invitation + active state

- `enum :role, { admin: 0, facilitator: 1, participant: 2 }` —
  predicates `facilitator?` / `admin?`, scopes `User.facilitator`.
- Invitation columns: `invitation_token`, `invitation_sent_at`,
  `invitation_accepted_at`.
- `invitation_expired?` — 7 days for facilitators (`INVITATION_EXPIRY`
  on user.rb:20-24).
- `accept_invitation!` clears the token and sets the timestamp.
- **No `deactivated_at`, no soft-delete, no status enum.** Users are
  permanent.

This is why "deactivate an active facilitator" is explicitly out of
scope — there's no plumbing for it, and adding it is its own design.

### Existing admin/facilitators index

`app/views/admin/facilitators/index.html.erb` lines 35-65. Each card
has the layout we want to extend:

- Avatar, name, email, optional workshop-list line, status badge.

For this spec:

- Wrap the card content in a link to `admin_facilitator_path`.
- Add a small "Revoke" button next to the "Invitation pending" badge
  (pending only).
- Keep the existing workshop-titles join — it's a nice at-a-glance
  signal.

### Existing routes

`config/routes.rb:75-82`:

```ruby
namespace :admin do
  resources :facilitators, only: [ :index, :new, :create ]
  resources :workshops, only: [], param: :slug do
    resources :emails, only: [ :index, :new, :create ], controller: "workshop_emails" do
      post :send_test, on: :collection
    end
  end
end
```

Need to extend `:facilitators` with `:show, :destroy` plus the nested
`:workshop_assignments`.

---

## Things to verify during implementation

- The `dependent: :destroy` on `User#workshop_participations` covers
  the cascade for pending-invitation revocation, but write a test
  that explicitly verifies: a pending facilitator with one
  pre-assigned `WorkshopParticipation` → revoke → row is gone.
- `find_or_create_by!` is the right idempotent shape, but verify in
  a test that two rapid POSTs from the form don't surface as a 422
  to the user. The flash should remain `notice`, not `alert`.
- For unassign: confirm the redirect target is the show page (not
  the index) so the admin can see the updated state immediately.
- Workshop dropdown content: scope to
  `Workshop.all.order(:starts_on) - facilitator.workshops`. The
  subtraction needs `id`-based diffing if Rails is fussy about
  identity equality (`pluck(:id)` + `where.not(id: ...)`).
- The `Admin::FacilitatorsController#destroy` refusal-for-accepted
  path: test it. UI hides the button, but a curl POST shouldn't be
  able to wipe an active facilitator.
- Confirm dialogs use the project's Turbo-modal pattern
  (`<turbo-frame id="modal">` layout slot + `modal_controller.js`),
  per `MEMORY.md`. Do **not** use `data-turbo-confirm`. Do **not**
  add a new overlay slot. Pattern reference: the glossary delete
  flow already uses this — copy that shape.
- Browser smoke before PR: log in as admin, create a new pending
  facilitator, assign two workshops at invite time, verify both
  participations exist, revoke the invitation, verify the user and
  both participations are gone. Then assign Lauren (already in prod)
  to the Italian workshop via the new UI to confirm the manual
  console fix can be repeated through the app.

---

## Implementation slice order (TDD)

1. Routes — extend `admin/facilitators` with `:show, :destroy` and the
   nested `workshop_assignments`. Failing route test.
2. `Admin::FacilitatorsController#show` — failing controller test,
   then view.
3. `Admin::FacilitatorWorkshopAssignmentsController#create` — failing
   model-level test (`WorkshopParticipation` row written), failing
   integration test (`manageable_by?` flips), then controller and
   form on the show page.
4. `Admin::FacilitatorWorkshopAssignmentsController#destroy` — same
   shape; verify `manageable_by?` flips back.
5. `Admin::FacilitatorsController#destroy` — failing test for pending
   revocation, failing test for accepted refusal, then controller.
6. Index — link wrap + inline "Revoke" for pending.
7. Invite + assign — extend `new` form, extend `create` controller
   with the transaction. Failing test for two-row creation; failing
   test for rollback on invalid workshop_id; failing test for
   today's no-workshop-ids behaviour staying intact.
8. I18n sweep across en/es/it/el.
9. YARD docs on new controllers and any helper additions.
10. Record the two new decisions via
    `bundle exec munkit decide "<title>"` (facilitator-centric admin
    surface; pending-invitation = hard-delete, accepted-facilitator
    removal = out of scope). The role-agnostic
    `WorkshopParticipation` decision is **not** re-recorded —
    `DECISIONS.md` 2026-04-25 already covers it.
11. Self-review with `rails-code-review`. Browser smoke. PR.

---

## Open questions

- **Confirm-dialog copy for "Unassign".** Current draft: "Lauren will
  lose edit access to *Taller IMASUS España*. Her existing data
  stays." Worth A/B-ing the wording with the user before
  implementation, but not blocking the spec.
- **Should the show page also display projects/log entries authored
  by the facilitator in each workshop?** Useful as a "what would I
  lose visibility into if I unassigned" cue, but adds query weight.
  Defer to a follow-up unless the user wants it now.

## Out-of-spec markers to remove

- None — this is purely additive.

## TDD / workflow reminders

Per `CLAUDE.md`: **Tests → Implementation → YARD → Docs →
Self-review (`rails-code-review`) → PR**. Minitest only. No RSpec.
