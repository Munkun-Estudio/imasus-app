# Notes: 2026-04-29-admin-workshop-emails

Scratch space and rationale for the lightweight admin broadcast email spec.

---

## Open Questions

- Should the composer live under each workshop (`/admin/workshops/:slug/...`)
  or under a broader admin communications area with workshop as a required
  field? Default assumption in the brief: workshop-scoped routes.
- Should the editor be Action Text/Trix or a simpler HTML-safe composer? The
  brief allows either, as long as the result is HTML email plus text fallback.

## Ideas

- Reuse existing workshop participants/facilitators associations rather than
  introducing a parallel mailing-list model in v1.
- Persist send batches so the admin can review sent messages later and resend
  manually if needed in a future spec.
- Keep the audience selector intentionally coarse:
  participants / facilitators / both.

## Research

- Current project context and memory say the app sends transactional emails
  only. This spec is intentionally narrower than a newsletter system and
  should be described that way if it changes `MEMORY.md` later.
- Existing production mail path is SES SMTP (`MEMORY.md` Deployment), so the
  implementation can build on the established mailer stack rather than adding
  a new provider.
