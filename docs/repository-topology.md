# Generic upstream and installation downstreams

This repository is the canonical generic application. Organisation-specific
deployments, including IMASUS, live in separate downstream repositories.

## Ownership boundary

The generic upstream owns:

- shared Rails application code and database migrations;
- the versioned installation-profile contract;
- neutral example profiles and content;
- provider-portable Docker packaging, tests, and release metadata;
- the Scaleway reference deployment documentation.

An installation downstream owns:

- its profile, brand assets, legal copy, locales, and content manifests;
- installation-specific media and their licences;
- deployment/IaC configuration, secrets, domains, and operational runbooks;
- partner attribution and any installation-only compatibility adapters;
- production data, backups, monitoring, and incident response.

## IMASUS transition

IMASUS is currently both the originating installation and the production
compatibility fixture. Split it without interrupting `app.imasus.eu`:

1. Finish and tag the generic v1 release candidate while the existing Fly
   deployment remains active.
2. Create a separate IMASUS repository from the reviewed release history.
3. Configure this repository as its `upstream` remote and keep IMASUS changes on
   its own default branch.
4. Move the `imasus` profile, content, assets, legal text, Fly configuration,
   and deployment workflow to the downstream.
5. Restore a representative production backup in a rehearsal environment and
   verify URLs, attachments, bookmarks, users, and migrations.
6. Move continuous deployment and only then cut over the production domain.
7. Remove IMASUS-only content and Fly deployment files from the generic
   upstream after the downstream has passed its observation window.

Creating the downstream repository, moving secrets, changing DNS, and removing
the current deployment are separate actions requiring explicit approval.

## Receiving upstream releases

The downstream records the upstream version it consumes and merges reviewed
upstream release tags rather than copying individual files. Before every
upgrade it runs its profile diagnostic, CI matrix, migration rehearsal, backup,
and rollback checklist. Installation-only patches should be proposed upstream
when generally useful; otherwise they remain small and isolated downstream.

Exact repository names and any rename of the current GitHub repository must be
chosen before creating the Zenodo record, because repository and citation URLs
become part of the permanent release metadata.
