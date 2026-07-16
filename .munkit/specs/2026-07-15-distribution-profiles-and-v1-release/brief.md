# Distribution profiles and v1 release

## What

Package the generic application, IMASUS installation, and a minimal example as
documented profiles; test their configuration matrix; and prepare the repository
metadata, upgrade path, and release process needed for a trustworthy v1.0.0.

## Why

Reusability is not proven by abstraction alone. A new organisation must be able
to clone, configure, populate, run, test, deploy, and cite the application, while
the current IMASUS deployment remains operable and maintainable.

## Acceptance Criteria


- [ ] The repository includes documented IMASUS and minimal example profiles,
  example content, and a clone-to-local-run quickstart that requires no edits to
  shared application code.
- [ ] CI validates the full IMASUS profile and a deliberately different minimal
  matrix (brand, locales, and enabled modules), including configuration doctor,
  migrations, tests, and asset compilation.
- [ ] Deployment documentation identifies profile selection, required secrets,
  storage, mail, analytics, host/CORS settings, backups, migration order, and
  rollback without embedding IMASUS-only defaults in reusable templates.
- [ ] Upgrade documentation covers existing IMASUS data and URLs, and a rehearsal
  verifies upgrade and rollback against a representative backup.
- [ ] `README`, license, contributor guidance, changelog, citation metadata, and
  Zenodo-compatible release metadata describe the generic project and credit the
  originating project appropriately.
- [ ] A release checklist defines integration-branch/child-PR flow, repository
  topology and deployment cutover decision points, semantic version/tag creation,
  GitHub release, Zenodo archival, and EPALE communication as separately approved
  actions.
- [ ] A v1.0.0 release candidate passes the sprint-level compatibility and adopter
  walkthrough before any production cutover or public release.

## Out of Scope


- Performing a production deployment, moving repositories, publishing a GitHub
  release/Zenodo record, or posting to EPALE without explicit approval.
- Supporting every hosting provider or operating system.

## Notes

This is the final integration spec and depends on all preceding sprint specs. The
canonical generic repository versus IMASUS downstream structure should be chosen
from the proven release candidate, not assumed at the start of the refactor.
