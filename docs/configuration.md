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
| `locales` | Ordered available locales and the default locale |
| `modules` | Availability of Library, Guides, Prompts, and Glossary |
| `content` | Repository-relative content root and guides directory |
| `public_urls` | Canonical application, fallback, project, and source URLs |
| `operations.analytics` | Whether analytics is enabled and its public script URL |

The contract is strict:

- Unknown or missing keys stop application boot with an actionable error.
- Locale values must be unique and the default must be enabled.
- Module flags must be explicit booleans.
- Content paths must be relative, stay inside the repository, and exist.
- Public URLs must be absolute HTTP or HTTPS URLs.
- Analytics requires a script URL when enabled; use `null` when disabled.
- Unsupported profile versions are rejected instead of being guessed.

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
2. Replace every public value explicitly.
3. Add the referenced content directories.
4. Run `APP_PROFILE=your_profile bin/site-config`.
5. Run the test suite with that same `APP_PROFILE`.

Later v1.0.0 sprint specs will make brand assets, labels, module behaviour, and
content manifests consume this boundary. The first configuration spec only
establishes and validates the contract while preserving current IMASUS behaviour.
