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
- deployment/IaC configuration, secret names, domains, and operational
  runbooks (secret values stay outside Git);
- partner attribution and any installation-only compatibility adapters;
- production data, backups, monitoring, and incident response.

## IMASUS transition

IMASUS is currently both the originating installation and the production
compatibility fixture. Its long-term public presence will instead be the static
archive in the separate `imasus-app-static` repository, deployed to Netlify at
`app.imasus.eu`. Split and retire the live Rails runtime without losing the
ability to run future workshops:

1. Finish and tag the generic v1 release candidate while Fly remains active.
2. Create a separate IMASUS Rails repository from that reviewed release and
   configure this repository as its `upstream` remote.
3. Move the `imasus` profile, content, assets, legal text, deployment templates,
   and revival runbook to that downstream. Keep CI automatic but deployment
   manual so repository updates cannot create billable infrastructure.
4. Complete the production-to-static export, privacy review, asset manifest,
   database backup, and object-store backup.
5. Deploy `imasus-app-static` to a Netlify preview and verify it on a temporary
   hostname, including direct media URLs and legacy public routes.
6. Point `app.imasus.eu` to Netlify, disable the automatic Fly workflow, and
   stop the Rails compute/database for a defined rollback window.
7. After the static archive passes that window, remove Fly compute, database,
   volumes, certificates, secrets, and CI credentials separately. Do not remove
   Tigris while the archive still references it; migrate those objects first or
   retain the bucket intentionally.
8. Remove IMASUS-only content and Fly deployment files from the generic
   upstream after the downstream and recovery artifacts are verified.

Creating the downstream repository, moving secrets, changing DNS, and removing
the current deployment are separate actions requiring explicit approval.

## Dormant IMASUS workshop runtime

The IMASUS downstream is a deployment-ready source repository, not an always-on
service. It retains the selected upstream version, IMASUS profile/content,
infrastructure templates, `.env.example`-style secret names, and a tested
provision/deploy/retire runbook. It does not retain credentials or production
data in Git and does not deploy on every push.

For a future workshop, provision infrastructure through a manual, approved
workflow and choose explicitly between a fresh database seeded with IMASUS
content or restoring the encrypted historical snapshot. Use a workshop-specific
hostname by default: `app.imasus.eu` remains the canonical static archive unless
a separate domain change is approved. Retire the runtime again after the
workshop and preserve any required export and backup.

## Receiving upstream releases

The downstream records the upstream version it consumes and merges reviewed
upstream release tags rather than copying individual files. Before every
upgrade it runs its profile diagnostic, CI matrix, migration rehearsal, backup,
and rollback checklist. A release update must not trigger deployment while the
runtime is dormant. Installation-only patches should be proposed upstream
when generally useful; otherwise they remain small and isolated downstream.

Exact repository names and any rename of the current GitHub repository must be
chosen before creating the Zenodo record, because repository and citation URLs
become part of the permanent release metadata.
