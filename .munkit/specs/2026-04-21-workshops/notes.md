# Notes: 2026-04-21-workshops

Scratch space for working through this spec. Delete when done.

---

## Baseline from spec 8

- `Workshop` already exists as a minimal model with `title`, `location`, and
  `slug` in the schema, but only `title` + `location` are validated/used.
- `WorkshopParticipation` already exists and is exercised by the invitation
  flow. This spec should preserve that join model and not re-split the concept.
- `WorkshopsController#index` is currently a placeholder public page.
- `WorkshopsController#show` currently requires login and renders a minimal
  title/location page.
- Facilitator/admin invitation flow already lives under
  `/workshops/:workshop_id/invitations` and redirects back to the workshop show
  page after inviting participants.

## Decided

- **Workshop titles are translatable.** `title` should follow the same
  multilingual surface as the description rather than stay a plain string.
- **Workshop content may be locale-sparse.** If a workshop only has Spanish,
  Italian, or Greek copy, that is valid input. The model/seed flow should not
  require English content or emit warnings just because other locales are blank.
- **Agenda should support Trix authoring later.** That pushes the storage shape
  toward locale-aware rich text (for example one Action Text field per locale)
  instead of plain translated text rendered with `simple_format`.
- **Signed-in users can browse all workshops.** Participant visibility is not
  restricted to only their attached workshop(s) in this spec.
- **Implement against Spain first.** Only the Spain workshop is treated as
  canonical seed content for this pass; Greece and Italy stay deferred until
  their details are confirmed.
- **Known date so far: 2026-04-28.** Treat April 28, 2026 as the currently
  confirmed workshop date for the Spain seed. Do not invent extra webinar or
  in-person dates until the organisers confirm whether the two-session format is
  being scheduled as one date or multiple dated touchpoints.

## Ideas

- Make the workshop detail page the "orientation hub" for each workshop:
  overview first, agenda second, project work later.
- Reuse the calm editorial tone from materials/glossary rather than introducing
  admin-heavy layouts just because workshops have dates and partner metadata.
- Keep agenda authoring UI out of spec 9, but choose a storage/rendering shape
  now that spec 13 can wire into a facilitator-facing Trix form without another
  migration.

## Scope expansion during review

The spec's strict surface is the workshops pages, but review of the implemented
work surfaced UI debt in neighbouring authenticated surfaces that was too ugly
to ship alongside a polished workshops index. The following was bundled into
this spec as corrective polish rather than deferred to a dedicated UI spec:

- Extracted shared form styling into `app/helpers/form_ui_helper.rb` (card,
  label, input, textarea, primary button, secondary link, error box) plus a
  tooltip helper, and adopted it across `sessions/new`, `password_resets/new`
  and `edit`, `admin/facilitators/new`, `facilitator_invitations/edit`,
  `participant_invitations/edit`, and `workshop_invitations/new`.
- Added the `information_circle` heroicon to support the new tooltip helper.
- Enriched `config/locales/*.yml` with `errors.messages`,
  `activerecord.attributes.user`, and full es/it/el translations for the auth
  and invitation forms. Overrode `date.formats.default` / `long` to
  `%d/%m/%Y` across all locales so workshop dates render the European way in
  every UI, including English.
- Participant invitation form dropped the password-confirmation field — see
  the 2026-04-21 entry in `.munkit/DECISIONS.md` for rationale and scope.
- Mailer now renders the participant invitation in
  `workshop.communication_locale`, preferring the workshop's local language
  over English when content is present.

If any of these land in a future review as contested, they should migrate into
their own spec rather than growing this one further.

## Research

- Current repo evidence:
  `app/models/workshop.rb`
  `app/models/workshop_participation.rb`
  `app/controllers/workshops_controller.rb`
  `app/controllers/workshop_invitations_controller.rb`
  `app/services/invite_participants_to_workshop.rb`
  `app/views/workshops/index.html.erb`
  `app/views/workshops/show.html.erb`
  `test/controllers/workshops_controller_test.rb`
