# Application configuration foundation

## What

Introduce a single, versioned application configuration contract and loader for
installation-level settings. Ship the current IMASUS values as the default
profile so the first refactor changes structure, not behaviour. Configuration
must be validated at boot and inspectable with a diagnostic command.

## Why

Brand, locales, tools, URLs, and content assumptions currently live across Ruby,
views, JavaScript, stylesheets, mailers, and deployment files. A stable boundary
is required before those concerns can be extracted safely and incrementally.

## Acceptance Criteria

- [x] A documented, versioned configuration file defines installation identity,
  locales, modules, content locations, public URLs, and non-secret operational
  settings with explicit defaults.
- [x] Application code accesses configuration through one typed/read-only API;
  validation reports actionable errors for missing, unknown, or incompatible
  values before serving requests.
- [x] Secret values remain in Rails credentials or environment variables and the
  configuration contract documents those references without storing secrets.
- [x] The default IMASUS profile reproduces all values currently hardcoded in the
  application, and existing tests pass without user-visible changes.
- [x] A diagnostic command prints the active profile, validates referenced files,
  and exits non-zero for an invalid installation.
- [x] Configuration behaviour, precedence, and extension rules have focused tests
  and adopter documentation.

## Out of Scope


- Extracting branding, locales, or module behaviour beyond replacing direct
  constants with the configuration boundary.
- Runtime or per-user configuration changes.

## Notes

This is the dependency for every other sprint spec. Prefer an explicit contract
over scattering environment-variable reads throughout the codebase.
