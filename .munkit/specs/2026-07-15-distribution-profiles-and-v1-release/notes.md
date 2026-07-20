# Notes: 2026-07-15-distribution-profiles-and-v1-release

## Initial discovery

- `fly.toml` fixes the current app name, region, storage volume, and runtime
  choices; deployment templates need clearly marked installation values.
- The existing application is the compatibility fixture and should remain the
  deployed public site while the abstraction is developed and verified.
- The proposed delivery model is a long-running `codex/v1.0.0` integration branch
  with one child PR per sprint spec, squash-merged into it; the final integration
  into `main` intentionally preserves the reviewed release boundary.
- GitHub release/tag creation must precede Zenodo archival; EPALE communication
  is dissemination work after the release exists and has a stable citation.
- The first adopter walkthrough exposed two hidden IMASUS dependencies in the
  minimal profile: its initial workshops came from the global IMASUS seed and
  its assets referenced the current logo/icons. Workshop seeds are now selected
  through `content.workshops`; the minimal manifest is empty and its optional
  brand assets are `null`.
- Generic `ADMIN_EMAIL`, `ADMIN_NAME`, and `ADMIN_PASSWORD` seed variables are
  the documented interface. Existing `IMASUS_ADMIN_*` names remain compatible
  for the deployed profile.
- CI uses two explicit application profiles. IMASUS runs the full historical
  compatibility suite; minimal runs its isolated smoke test. Both profiles run
  the configuration diagnostic, prepare the migrated test database, and compile
  production assets. Security, JavaScript audit, lint, and IMASUS system tests
  remain shared jobs rather than being duplicated by profile.
- The isolated minimal smoke test renders the application layout and therefore
  needs `tailwind.css` before the later production precompile step. CI builds
  Tailwind immediately before that smoke test so a clean checkout behaves like
  the locally verified worktree.
- The generic deployment reference is Scaleway in one European region:
  Serverless Containers, Container Registry, Managed PostgreSQL, Object
  Storage, Private Network, Transactional Email, and Serverless Jobs for
  migrations. Fly remains only as the transitional IMASUS deployment.
- Repository topology is resolved as generic upstream plus a separate IMASUS
  downstream. Repository names and the production cutover remain later explicit
  decisions/actions because they affect stable citation URLs and live service.

## Open questions

- Confirm content licensing and partner attribution before generating final
  citation and Zenodo metadata. The original software licence is confirmed as
  MIT, Copyright (c) 2026 Munkun; content, media, names, logos, trademarks, and
  third-party works are not included automatically in that grant.
