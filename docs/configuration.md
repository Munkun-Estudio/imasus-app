# Installation configuration

IMASUS App loads one checked-in installation profile at boot. Profiles define
public, non-secret settings that differ between installations while application
code reads them through one immutable object:

```ruby
Rails.configuration.site
```

The default profile is
[`config/profiles/imasus.yml`](../config/profiles/imasus.yml). Select another
profile by its filename, without the extension:

```bash
APP_PROFILE=my_organisation bin/dev
```

The loader resolves that value to `config/profiles/my_organisation.yml`. Profile
names may contain lowercase letters, numbers, underscores, and hyphens. There is
no field-by-field environment override and profile files do not execute ERB.
This keeps the effective configuration reviewable and reproducible.

## Contract

Every profile declares `version: 1` and all of the following sections:

| Section | Purpose |
| --- | --- |
| `identity` | Public application, short, and organisation names |
| `locales` | Ordered locales, display labels, and default/fallback locales |
| `modules` | Availability and localized labels for resource modules |
| `content` | Repository-relative content root and Library, Guides, Prompts, and Glossary manifests |
| `public_urls` | Canonical application, fallback, project, and source URLs |
| `operations.analytics` | Whether analytics is enabled and its public script URL |
| `brand.assets` | Logo, compact mark, email/social images, favicons, and manifest |
| `brand.theme` | Six validated semantic colour roles |
| `brand.email` | Non-secret default sender identity |

The contract is strict:

- Unknown or missing keys stop application boot with an actionable error.
- Locale values must be unique; the default and fallback must be enabled.
- Every enabled locale must have one non-empty display label.
- Every supported resource module must have one label per enabled locale.
- Module flags must be explicit booleans.
- Content paths must be relative, stay inside the repository, and exist.
- Public URLs must be absolute HTTP or HTTPS URLs.
- Analytics requires a script URL when enabled; use `null` when disabled.
- Unsupported profile versions are rejected instead of being guessed.
- Brand assets must resolve to existing asset-pipeline or public files.
- Theme values must be six-digit hexadecimal colours.
- The default sender address must be a valid email address.

Application code should read `Rails.configuration.site` and must not parse the
YAML directly. Additions to the contract require a versioning and compatibility
decision rather than silent, consumer-specific defaults.

## Secrets

Do not put passwords, access keys, tokens, private keys, or API keys in a
profile. Secret-like keys are rejected. Continue to use Rails credentials or
environment variables for database, storage, email, and deployment credentials.
The profile may contain public service metadata such as an analytics script URL.

## Validation

Run the standalone diagnostic before booting or deploying:

```bash
bin/site-config
APP_PROFILE=my_organisation bin/site-config
```

It prints the selected profile, resolved content paths, enabled locales and
modules, public URL, and analytics state. It exits non-zero when the profile is
missing or invalid.

## Creating another profile

1. Copy `config/profiles/imasus.yml` to a lowercase profile name.
2. Set `locales.available` in the order used by selectors and editors.
3. Add one `locales.labels` entry per locale, then choose enabled `default`
   and `fallback` locales.
4. Replace every other public value explicitly.
5. Add the referenced content directories and manifests.
6. Run `APP_PROFILE=your_profile bin/site-config`.
7. Run the test suite with that same `APP_PROFILE`.

Module behaviour and the Guides, Prompts, and Glossary manifests consume this
boundary. Brand assets, identity, metadata, email defaults, analytics, and
semantic theme roles also use it while preserving current IMASUS behaviour.

See [Branding an installation](branding.md) for the asset convention, theme
roles, localized identity placeholders, email defaults, and optional-service
behaviour.

See [Resource modules](modules.md) for module keys, route compatibility,
disabled-module behaviour, bookmark integration, and the minimal profile.

See [Guide content](guides.md) for the validated content manifest, locale
fallback behaviour, and the content-only add/remove workflow.

See [Library content](library.md) for reusable item types, structured fields,
taxonomies, links, publication, and the Materials compatibility migration.

See [Prompt and glossary catalogues](catalogs.md) for their manifest schema,
stable-ID rules, synchronization, publication, and retirement behaviour.
