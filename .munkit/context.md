# Project Context

Deep product and domain context for this project. Unlike MEMORY.md (which is structured),
this file is free-form for anything agents should know about the product shape.

---

IMASUS App should feel like a serious but inviting workshop tool. It is not an LMS clone and not a generic admin dashboard. The product needs to support collaborative learning, reflection, and challenge-framing without overwhelming participants with operational complexity.

## Product Model

### Workshop lifecycle

The app is used **before, during, and after** the physical workshop:

- **Before:** participants register (via invitation link from facilitator), browse the materials database, complete training modules, explore challenges.
- **During:** participants create a project (solo or team), pick a challenge, take photos and videos, write log entries documenting their process, reference materials and training content.
- **After:** participants reflect on their experience and publish a public project page — a Behance-style case study summarising their process and results. This is a portfolio piece, not an evaluated submission.

### The central object is the Project

A Project is created by a participant during a workshop. It accumulates log entries (text, photos, videos, material references) and culminates in a published public page. The project is the unit of work, collaboration, and publication.

- A project belongs to a workshop and optionally links to a challenge.
- A project has one or more members (participants). The creator is the owner; they can add other registered participants at any time.
- A participant can belong to multiple projects (no restriction).
- The process log belongs to the project, not the individual. All members contribute to the same log.
- No private notes — everything in a project is visible to all members and to the workshop facilitator.
- Projects start as **draft** (work-in-progress, visible within the workshop) and can be **published** (public URL, visible to anyone). Publishing includes a guided reflection/wizard step to help students curate their process into a presentable summary.

### Visibility and privacy

- **Within a workshop:** all participants see all projects. You can browse other teams' work, but only edit your own.
- **Published projects:** visible to anyone via public URL. No login required. The IMASUS website can list workshops and link to published project pages.
- **Log entries:** visible to project members and facilitators only (not published unless the participant includes them in the public page summary).
- **Materials, training modules, glossary, and challenges:** public content, no login required.

### Roles

Three roles: **admin**, **facilitator**, **participant**.

- **Admin** (project owner): creates facilitator accounts, has full access.
- **Facilitator:** creates and manages workshops; invites participants (sends email with registration link); can view all projects in their workshops; can moderate (disable participants or projects in case of conflict). Does not evaluate or grade.
- **Participant:** a student or young professional. Self-registers via invitation link from a facilitator. Joins workshops, creates projects, logs process, publishes. Can participate in multiple workshops and projects.

### Registration and invitation

- Participants register via **invitation-only**: facilitator enters participant emails → app sends invitation email with a token link → participant clicks, lands on registration form pre-associated with the workshop.
- Registration collects: full name, email, password, institution, country, short bio/interests, links (LinkedIn, Instagram, Behance, etc. — open-ended).
- Facilitators are created by admin and receive an email to set up their account.
- Transactional emails only: registration, password recovery, invitation. No notifications.

### Rich content and embeds

- Log entries and the published project page use **Action Text** (Trix) for rich text editing.
- A toolbar button allows participants to **quote/embed materials** from the database and **reference training module passages** — rendering as rich link cards with thumbnail, title, and key properties.
- Material embeds and training module references should render as recognisable, styled cards within the text flow.

### Media and images

- Participants upload photos and videos in log entries.
- Materials have multiple images (professional photos + micrographs with SEM metadata) and videos.
- **Image hosting:** AWS S3 via Active Storage (the project already uses AWS for the IMASUS newsletter). CDN strategy for image variants and optimisation to be decided in a dedicated spec, before any image-heavy feature is built.
- Micrographs are a large dataset — performance and lazy loading matter.

### Workshops

- Three known workshops: Greece, Italy, Spain. Seeded from provided data.
- Each workshop has a title, location, partner, dates, description, and a custom agenda page.
- All content (materials, training, glossary, challenges) is shared across workshops. Only the agenda differs per location.
- No formal phases/states — when participants register, they can access available workshops and participate immediately.

### Content sources

- **Training modules:** exist as markdown files in the IMASUS Bridgetown site repo at `/Users/pablo/projects/imasus/src/training-modules`. 4 modules × 3 sections × 4 locales (en/es/it/el). Will be copied into this project.
- **Materials CSV:** work in progress at `docs/materials-db.csv`. Mostly lacks the large set of micrograph images and videos. Image integration depends on the CDN/storage strategy.
- **Glossary terms:** may be embedded in training module content. Needs research to extract as structured data.
- **Challenge descriptions (C1–C10):** exist as a WIP DOCX/PDF.

### I18n

Four locales: **en** (base), **es**, **it**, **el** (Greek — ISO 639-1 code, not "gr").

- All user-facing strings go through `t(...)` from day one.
- Training module content is already multilingual (files per locale).
- Materials, challenges, glossary: translatable fields (approach TBD — locale-suffixed columns or JSONB).

### What is explicitly out of scope

- Evaluation / grading / scoring of prototypes.
- In-app messaging or notifications (beyond transactional emails).
- Mobile-first design (desktop/laptop-first, with responsive mobile support).
- Gamification.

---

## Design Context

### Users

- Primary users are participants (students and young professionals) attending IMASUS workshops.
- Secondary users are facilitators who guide the workshop process and need clarity on progress, prompts, and outputs.
- The product is used in educational and collaborative contexts where participants are trying to move from a broad challenge to concrete ideas and early solution concepts.

### Brand Personality

- The interface should feel thoughtful, optimistic, and well-structured.
- Tone words: human, exploratory, rigorous.
- It should not feel bureaucratic, gamified for its own sake, or visually interchangeable with a startup CRM.

### Aesthetic Direction

- Prefer a light-first editorial interface with workshop-canvas energy rather than a dense control panel.
- IMASUS brand palette: Dark Green `#1F3D3F`, Navy `#252645`, Red `#FA3449` (accent, sparingly), Mint `#AFE0C7`, Light Blue `#AFCEDE`, Light Pink `#FFC2D7`.
- Typography: General Sans (with Arial fallback).
- Favor clear sectioning, legible typography, and strong content hierarchy over decorative chrome.
- Avoid noisy dashboards, card walls with little narrative structure, and novelty interactions that would distract in a classroom.
- Design for both desktop and laptop-first workshop use; mobile support matters, but the core experience is not mobile-primary.

### Accessibility

- Target WCAG 2.1 AA. Not formally mandated, but desirable for an EU-funded educational project.
- Strong contrast, keyboard reachability, readable spacing, and language understandable for mixed-discipline participants.

### Review Priorities

- Focus reviews on clarity of progression, accessibility, and whether each screen helps participants understand the current workshop step.
- Do not regress the onboarding and workshop navigation surfaces once they exist; those are likely to become the core orientation layer.

---

## Domain Model (sketch)

This is a working sketch, not a migration plan. It will evolve as specs are implemented.

```
User (name, email, password_digest, role [admin/facilitator/participant],
      institution, country, bio, links)
  │
  ├── WorkshopParticipation (join: user ↔ workshop)
  │
  ├── ProjectMembership (join: user ↔ project, role [owner/member])
  │
Workshop (title, location, partner, dates, description, agenda_content)
  │
  ├── Project (title, challenge, workshop, description,
  │           status [draft/published], published_at)
  │     ├── LogEntry (body [Action Text], media [Active Storage],
  │     │            material references, created_by)
  │     ├── ProjectMaterial (join: project ↔ material, usage_note)
  │     └── Public page fields on Project: hero_image, problem_statement,
  │           process_summary [Action Text], key_insights, risks
  │
Material (trade_name, slug, category, material_of_origin, application,
          availability, links, description, structure,
          interesting_properties, retails, SEM metadata fields)
  ├── MaterialImage (Active Storage, SEM metadata: HV, magnification,
  │                  WD, detector, pressure)
  ├── Tag / Tagging (property tags for filtering)
  │
Challenge (code [C1–C10], category [material/design/system/business],
           question, description)
  │
GlossaryTerm (term, definition, examples, category)
  │
TrainingModule (PORO — reads markdown from disk, not a DB model.
                Knows slug, available locales, sections.)
```

---

## Implementation Plan (spec list)

Specs are created under `.munkit/specs/` as work begins. This list is the agreed sequence.

| # | Spec slug | What | Depends on |
|---|-----------|------|------------|
| 1 | `app-shell-and-navigation` | Sidebar nav (7 items), responsive layout, footer, Tailwind palette tokens, General Sans, I18n setup (en base, es/it/el stubs) | — |
| 2 | `training-modules` | PORO loader, markdown renderer, controller (index + show), locale switcher, chapter nav (prev/next). Copy content from Bridgetown repo. | 1 |
| 3 | `image-hosting-strategy` | Architecture decision: S3 + CDN config, Active Storage integration, image variant pipeline, lazy loading approach | — |
| 4 | `materials-database` | Material model, CSV seed task, Tag/Tagging, category filter, search, catalogue page, material detail page. Placeholder images until spec 3 is done. | 1, 3 |
| 5 | `glossary` | GlossaryTerm model, seed, glossary page with alphabetical nav + category pills, Stimulus popover for inline term highlighting | 1 |
| 6 | `challenge-cards` | Challenge model (C1–C10), seed, index grouped by category, reusable card component | 1 |
| 7 | `home-page` | Prompt cards, featured material, training carousel, CTAs. Pulls live data. | 2, 4 |
| 8 | `authentication` | User model (has_secure_password), admin/facilitator/participant roles, invitation flow, transactional emails | 1 |
| 9 | `workshops` | Workshop model, seed for 3 known workshops, index + detail + per-country agenda page, WorkshopParticipation join | 1, 8 |
| 10 | `projects-and-teams` | Project model, ProjectMembership, create project (solo or team), add members, link to workshop + challenge | 8, 9 |
| 11 | `process-log` | LogEntry with Action Text, timeline view, create entries with photos/videos/material references. Belongs to project. | 3, 10 |
| 12 | `project-publication` | Publishing wizard (guided reflection), draft→published lifecycle, public URL, Behance-style page with material/training embeds | 10, 11 |
| 13 | `facilitator-tools` | Workshop management, participant invitation UI, project moderation (disable participant/project), view all projects in a workshop | 8, 9, 10 |
| 14 | `workshops-public-listing` | Public page listing workshops and their published projects (no login required) | 9, 12 |

---

## Deployment

- Target: **Fly.io** with PostgreSQL.
- Image storage: **AWS S3** via Active Storage (existing AWS relationship from IMASUS newsletter).
- CDN / image optimisation strategy: TBD (spec 3).

## Concerns

Active cross-spec or cross-project concerns worth revisiting.
Keep entries short here and point to the detailed notes elsewhere.
Remove resolved items or promote them to MEMORY.md / DECISIONS.md when they become durable.

- Dependabot bundler updates fail: private munkit / munkit-symphony git sources unreachable from Dependabot's resolver. CI is mitigated by stripping munkit from Gemfile + regenerating Gemfile.lock; Dependabot itself needs a 'registries:' block in .github/dependabot.yml pointing at a PAT secret. Deferred — user will add the PAT.
