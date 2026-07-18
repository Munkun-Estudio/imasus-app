# Sprint: v1.0.0 — Configurable application foundation

Turn the current IMASUS application into a reusable, configuration-driven
workshop platform while preserving the behaviour, content, URLs, and deployment
of the existing IMASUS installation.

## Goal

By the end of the sprint, another organisation can clone the project, select a
brand, languages, and enabled tools, add its own library, guides, prompts, and
glossary content through documented manifests, and run the application without
editing application code. The IMASUS profile remains a tested first-class
installation and is visually and functionally unchanged.

## In Scope (Specs)

- [x] [Application configuration foundation](specs/2026-07-15-application-configuration-foundation/brief.md)
- [x] [Configurable brand and installation metadata](specs/2026-07-15-configurable-brand-and-installation-metadata/brief.md)
- [x] [Configurable locales and localized rich text](specs/2026-07-15-configurable-locales-and-localized-rich-text/brief.md)
- [x] [Optional module registry](specs/2026-07-15-optional-module-registry/brief.md)
- [x] [Manifest-driven guides](specs/2026-07-15-manifest-driven-guides/brief.md)
- [x] [Configurable prompts and glossary](specs/2026-07-15-configurable-prompts-and-glossary/brief.md)
- [x] [Generic library schema](specs/2026-07-15-generic-library-schema/brief.md)
- [ ] [Generic library presentation and media](specs/2026-07-15-generic-library-presentation-and-media/brief.md)
- [ ] [Distribution profiles and v1 release](specs/2026-07-15-distribution-profiles-and-v1-release/brief.md)

## Out of Scope (Deferred — record as decisions)

- A graphical administration interface for changing installation configuration.
- A runtime plugin marketplace or support for third-party executable plugins.
- Multi-tenant hosting of unrelated organisations in one deployment.
- Renaming or generalising the core workshop, project, team, membership, process
  log, and publication workflows.
- Moving the production deployment or changing repository ownership before the
  compatibility matrix and release candidate are proven.
- Publishing to Zenodo or announcing on EPALE; those dissemination steps follow
  the approved v1.0.0 release and require their own metadata and editorial work.

## Risks & Open Questions

- The current four-locale Action Text agenda schema needs a safe migration path;
  it must not lose embedded attachments or rich text.
- Existing URLs, bookmarks, imports, and Active Storage attachments couple the
  current content models to IMASUS terminology.
- A highly flexible JSON schema can become an accidental CMS. The v1 contract
  should support the known card/library use cases without promising arbitrary
  page building.
- Repository topology remains a release decision: this repository can host the
  integration work, while the canonical generic repository and IMASUS downstream
  relationship are chosen only after compatibility is demonstrated.

## Done When

- [ ] Every linked spec meets its acceptance criteria and has focused automated
  coverage.
- [ ] The full existing test suite passes under the IMASUS profile with no
  unexpected visual, URL, content, or deployment changes.
- [ ] A minimal example profile passes CI with a non-IMASUS brand, a reduced
  module set, and a different locale configuration.
- [ ] A new adopter can follow the documentation from clone to a working local
  installation using only configuration and content files.
- [ ] Upgrade, rollback, data migration, and release checks are documented.
- [ ] Work is integrated through a long-running `codex/v1.0.0` branch: one
  reviewable child PR per spec, squash-merged into the integration branch, then
  merged intentionally into `main` once the complete compatibility matrix passes.
