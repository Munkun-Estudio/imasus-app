# Spec — Admin Facilitator Management

## What

Extend the existing `/admin/facilitators` surface so admins can:

1. **See each facilitator's workshop assignments** on a dedicated
   facilitator page, not just on the index line.
2. **Assign a facilitator to a workshop** (creates a
   `WorkshopParticipation`).
3. **Unassign a facilitator from a workshop** (destroys the
   `WorkshopParticipation`; the facilitator immediately loses
   management access to that workshop but keeps the user account).
4. **Optionally assign workshops at invite time** as part of the
   existing "Invite facilitator" flow.
5. **Revoke a pending invitation** (hard-delete a facilitator user
   whose invitation has not been accepted).

All admin-only. No new model. No schema change. Builds on the existing
`WorkshopParticipation` join table.

Refer to this spec by slug: `admin-facilitator-management`.

## Why

In production we hit the exact failure mode this spec fixes: an admin
created a workshop, then invited a facilitator separately via
`/admin/facilitators/new`. The facilitator user record was created but
no `WorkshopParticipation` linking her to the workshop ever existed,
so `Workshop#manageable_by?` returned `false` and she could not edit
the workshop she was supposed to run.

The auto-attach in `WorkshopsController#create` only fires for the
**creator** of a workshop. There is currently no way to link a
facilitator to a workshop after the fact other than direct database
access. That is fragile, untraceable, and not something we want our
country teams to depend on.

The reverse failure (a facilitator who should no longer manage a
workshop) and the cleanup case (an invitation that was never
accepted — e.g. typo'd email) need the same admin surface to be
self-serviceable.

This spec also **closes the deferral recorded under spec 10**
(`DECISIONS.md` 2026-04-23 — *"facilitator draft access is
workshop-agnostic for MVP… `Project#visible_to?` grants all
facilitators read access to all draft projects until spec 13 adds
per-workshop facilitator assignment"*). Spec 13 shipped without that
tightening because there was no admin path to *establish*
per-workshop facilitator assignment in the first place. Once admins
can assign facilitators here, the workshop-agnostic facilitator
read-access in `Project#visible_to?` becomes the next thing to
tighten. We do **not** tighten it in this spec (see Out of Scope) —
but we name it so the follow-up isn't lost again.

We deliberately scope this admin-side, facilitator-centric (one page
per facilitator, listing their workshops) rather than workshop-side
("manage facilitators of this workshop") because:

- The single entry point `Manage facilitators` already exists on the
  admin home and is the natural mental model ("who has access to
  what" reads from the person).
- The dataset is small (a handful of facilitators, one or two
  workshops each); a facilitator-centric view scales fine.
- A workshop-side view can be added later if it becomes useful, but
  is not needed to unblock the bug.

## Scope

### `WorkshopParticipation` stays role-agnostic

This spec assigns and unassigns facilitators by creating and
destroying `WorkshopParticipation` rows directly, on top of the
**existing** role-agnostic join. The decision to keep that join
role-agnostic (rather than splitting facilitator vs participant into
separate models or adding a role column) was already made in
`DECISIONS.md` 2026-04-25 (Spec 13). We reuse that decision here
without revisiting it. The role check on `user.facilitator?` continues
to distinguish management from attendance, exactly as
`Workshop#manageable_by?` already implements.

### Routes

```ruby
namespace :admin do
  resources :facilitators, only: [ :index, :new, :create, :show, :destroy ] do
    resources :workshop_assignments, only: [ :create, :destroy ],
              controller: "facilitator_workshop_assignments"
  end
end
```

- `GET /admin/facilitators/:id` — show page.
- `DELETE /admin/facilitators/:id` — revoke pending invitation
  (destroys the user). Refuses for accepted facilitators (see below).
- `POST /admin/facilitators/:id/workshop_assignments` — assign to a
  workshop.
- `DELETE /admin/facilitators/:id/workshop_assignments/:id` — unassign
  from a workshop.

### `Admin::FacilitatorsController#show`

Renders the facilitator's name, email, status (Active /
Invitation pending), and:

- **Workshops assigned** — list of workshops they currently have a
  `WorkshopParticipation` on, each with an "Unassign" form button.
- **Assign workshop** — a small form with a single-select dropdown
  populated from `Workshop.all.order(:starts_on) - facilitator.workshops`,
  plus an "Assign" submit.
- **Revoke invitation** — visible only when
  `invitation_accepted_at.nil?`. Destructive action with a confirm
  dialog ("This will remove the invitation. The facilitator will not
  be able to use the original invitation link.").

**Confirmation dialogs use the project's Turbo-modal pattern**, not
`data-turbo-confirm`, per the convention recorded in `MEMORY.md`:
a dedicated GET action (e.g.
`GET /admin/facilitators/:id/workshop_assignments/:id/confirm_destroy`)
renders a partial wrapped in `<turbo-frame id="modal">` against the
layout-level slot in `application.html.erb`. The existing
`modal_controller.js` handles Escape, backdrop click, and focus
restore. Both "Unassign workshop" and "Revoke invitation" use this
pattern. Reuse the existing modal slot — do not introduce a new
overlay slot.

No edit-name, no edit-email, no resend-invitation in this spec —
deferred to a follow-up if needed.

### `Admin::FacilitatorWorkshopAssignmentsController`

Two actions:

- `create` — `WorkshopParticipation.find_or_create_by!(user: facilitator, workshop: workshop)`.
  Idempotent. Redirects to the facilitator show page with a flash.
  Refuses if the facilitator's `role` is not `facilitator` (defensive
  — the route is admin-only but the model contract is "facilitator
  attached" + role check).
- `destroy` — deletes the matching `WorkshopParticipation`. Redirects
  to the facilitator show page with a flash. Refuses if no matching
  row (404).

Both gated by `require_role :admin`.

### `Admin::FacilitatorsController#destroy`

- Only valid for **pending** facilitators
  (`invitation_accepted_at.nil?`). Accepted facilitators with content
  (projects, log entries) are out of scope for destruction in this
  spec; the path forward there is per-workshop unassignment.
- For pending facilitators, `user.destroy` cascades through
  `has_many :workshop_participations, dependent: :destroy` and any
  pre-assigned (but never used) workshop links.
- Redirect to `admin_facilitators_path` with a flash.
- If called on an accepted facilitator: redirect with an alert
  explaining that only pending invitations can be revoked. (Belt and
  braces — the UI hides the button in that case.)

### `Admin::FacilitatorsController#new` / `#create` — invite + assign

Extend the existing invite form:

- New optional multi-select `workshop_ids` (an HTML `<select multiple>`
  or a stack of checkboxes; design picks whichever fits the existing
  form styling). Empty submit behaves exactly as today.
- On `create`, if `workshop_ids` is present and non-empty: wrap the
  user save and the resulting `WorkshopParticipation.find_or_create_by!`
  calls in a single `ActiveRecord::Base.transaction`. Validation
  failure on either rolls both back; the form re-renders with errors.
- Invalid IDs (a workshop that does not exist) raise
  `ActiveRecord::RecordNotFound` from the controller's lookup, are
  rescued, and re-render the form with a generic error.

The `FacilitatorInvitationMailer.invite(...).deliver_later` call
happens **once**, after the transaction commits, exactly as today.
Assignment is silent — the email does not list workshops. (Mailer
copy update can be a separate follow-up if useful.)

### `Admin::FacilitatorsController#index` — small additions

- Each row becomes a link to `admin_facilitator_path(facilitator)`
  (the new show page).
- The existing inline workshop list (`facilitator.workshops.map(&:title).join(" · ")`)
  stays. No remove buttons inline — that lives on the show page to
  avoid one-click destructive actions buried in a long list.
- Pending facilitators get a small "Revoke" button on the index, in
  addition to the show-page action, because the "I typo'd an email"
  cleanup case benefits from one-click access. Confirm via the
  Turbo-modal pattern described above.

### Authorisation

| Action | Allowed when |
| --- | --- |
| All `/admin/facilitators*` routes | `current_user.admin?` |
| Workshop dropdown content | `Workshop.all` (admins see every workshop regardless of their own participation) |
| Unassign | Admin-only; idempotent at the model level (uniqueness on user_id + workshop_id) |
| Revoke pending invitation | Admin-only; refuses for accepted users |

### I18n

- New strings (show-page section headings, assign / unassign labels,
  revoke-invitation labels, confirm dialog copy, flashes) added to
  `en/es/it/el`.
- English fully filled. Spanish translated where copy is short.
  Italian and Greek carry English placeholders for longer copy plus
  translated short labels, marked with
  `# TODO: translate (admin-facilitator-management)`.

## Out of Scope

- **Tightening `Project#visible_to?` for facilitators** — the
  workshop-agnostic facilitator read-access deferred in
  `DECISIONS.md` 2026-04-23 (Spec 10) is **named** in Why above but
  not changed here. The follow-up spec scope: change
  `Project#visible_to?` so facilitators only see draft projects in
  workshops they have a `WorkshopParticipation` on. This spec
  unblocks that work by giving admins a way to *establish* those
  assignments, but doesn't ship the tightening itself — the change
  touches every place facilitators read project lists and needs its
  own test pass.
- **Workshop-side facilitator management** — no
  `admin/workshops/:slug/facilitators` surface. Defer until the
  facilitator-side proves insufficient.
- **Soft-delete / deactivation of accepted facilitators** — no
  `User.deleted_at` or active-flag column. Removing an accepted
  facilitator means unassigning them from each workshop; the user
  account stays. A future spec can add deactivation if needed.
- **Hard-deleting an accepted facilitator** — out of scope. Cascades
  through user-owned content (projects, log entries, bookmarks)
  warrant their own design pass.
- **Resending the invitation email** — useful but not required to
  unblock the current bug. Follow-up.
- **Editing a facilitator's name or email post-invite** — out of
  scope. Account self-service handles name; email change is rare
  enough to need a manual fix for now.
- **Workshop multi-select widget design** — pick whatever matches the
  existing admin form styling. No new component library.
- **Invitation email copy listing assigned workshops** — out of scope;
  silent assignment is fine.
- **Workshop-participation role column** — explicitly deferred; the
  current dual-purpose row is sufficient.
- **Audit log of admin actions** — out of scope.

## Acceptance Criteria

### Facilitator show page

- [ ] `GET /admin/facilitators/:id` renders for an admin.
- [ ] Non-admins are redirected with an access-denied flash.
- [ ] The page lists the facilitator's currently-assigned workshops
      (by title, ordered by `starts_on`).
- [ ] Each assigned workshop has an "Unassign" form button.
- [ ] The "Assign workshop" form lists every workshop the facilitator
      is **not** currently assigned to.
- [ ] The "Revoke invitation" button is visible only for pending
      facilitators.

### Assign workshop

- [ ] `POST /admin/facilitators/:id/workshop_assignments` with a valid
      `workshop_id` creates a `WorkshopParticipation` linking the
      facilitator to the workshop and redirects with a success flash.
- [ ] The facilitator can then load `/workshops/:slug/edit` for that
      workshop (i.e. `Workshop#manageable_by?` is now true).
- [ ] Submitting the same assignment twice does not raise — the
      idempotent `find_or_create_by!` returns the existing row and
      the user sees a non-error flash.
- [ ] Submitting a `workshop_id` that does not exist re-renders the
      show page with a generic error flash.
- [ ] An admin attempting to assign a workshop to a user whose role
      is **not** `facilitator` is refused with a flash explaining why.

### Unassign workshop

- [ ] `DELETE /admin/facilitators/:id/workshop_assignments/:id`
      destroys the matching `WorkshopParticipation` and redirects with
      a success flash.
- [ ] After unassignment, the facilitator can no longer load
      `/workshops/:slug/edit` for that workshop (redirected with
      access-denied).
- [ ] Projects, log entries, and other content authored within that
      workshop **are not destroyed**. They remain visible on the
      workshop and to admins.
- [ ] Unassigning a row that no longer exists returns 404 (don't
      double-handle).

### Revoke pending invitation

- [ ] `DELETE /admin/facilitators/:id` destroys the user when
      `invitation_accepted_at.nil?` and redirects to the facilitators
      index with a success flash.
- [ ] Any `WorkshopParticipation` rows pre-assigned during invite are
      cascade-destroyed (via `dependent: :destroy` on `User`).
- [ ] The original invitation link no longer authenticates — the
      `FacilitatorInvitationsController` already 404s on missing
      tokens; verify the existing behaviour holds.
- [ ] `DELETE /admin/facilitators/:id` on an accepted facilitator is
      refused with an alert flash; no destruction occurs.

### Invite + assign

- [ ] `POST /admin/facilitators` with no `workshop_ids` behaves
      exactly as today (user created, invitation email sent, no
      participations).
- [ ] `POST /admin/facilitators` with `workshop_ids: [a, b]`
      creates the user **and** two `WorkshopParticipation` rows in a
      single transaction. Both rollback together on validation
      failure (e.g. duplicate email).
- [ ] Invalid `workshop_ids` re-render the form with errors and no
      user is persisted.
- [ ] The invitation email is sent **once**, after the transaction
      commits.

### Index

- [ ] Each facilitator row links to the show page.
- [ ] Pending rows show a "Revoke" button with a confirm dialog.
- [ ] Accepted rows do not show a "Revoke" button.

### I18n

- [ ] All new copy reached through `t(...)` in en/es/it/el.

### Decisions

- [ ] Two new decisions recorded via
      `bundle exec munkit decide "<title>"`:
      (a) facilitator-centric admin surface (vs workshop-centric);
      (b) pending-invitation revocation as hard-delete of the
      `User` row, accepted-facilitator removal as out-of-scope.
      The `WorkshopParticipation`-stays-role-agnostic question is
      **not** re-recorded — `DECISIONS.md` 2026-04-25 (Spec 13)
      already covers it; cite it in the brief and notes instead.
      "No deactivation in this spec" is captured in Out of Scope
      and does not need a separate decision entry.

## Dependencies

- Spec 13 (`facilitator-tools`) — `Workshop#manageable_by?`,
  facilitator role, invitation lifecycle.
- Spec `2026-04-25-workshop-management` — workshop creation,
  auto-attach pattern (re-used here for the invite-and-assign
  transaction shape).
- Spec `2026-04-17-authentication` — invitation token, expiry,
  acceptance.

### Downstream / follow-ups (not part of this spec)

- **Workshop-side "Manage facilitators"** if the facilitator-centric
  surface proves insufficient.
- **Facilitator deactivation** (a `deactivated_at` column on `User`
  with login-gate plumbing) if "I want to keep their content but
  block all access" becomes a real ask.
- **Resend invitation** from the admin show page.
- **Workshop-participation role column** if the dual-purpose row
  becomes an actual problem (e.g. a facilitator who is also enrolled
  as a participant of a workshop they don't manage).
