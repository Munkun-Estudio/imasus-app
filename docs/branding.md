# Branding an installation

Brand identity belongs to the selected file under `config/profiles/`. Shared
views do not refer to IMASUS asset names, domains, or colour utilities.

## Identity and links

Set the public application name, short name, organisation, and default metadata
description under `identity`. The short name is used as accessible logo text and
as the visible fallback when a logo asset is absent.

`public_urls` contains the canonical application, hosting fallback, originating
project, source repository, and optional support URL. Support may be an HTTP(S)
URL or a `mailto:` link. The footer omits it when configured as `null`.

Localized content can use these reserved placeholders without changing every
call site:

```yaml
heading: "Welcome to %{app_name}"
account: "Your %{short_name} account"
owner: "Operated by %{organization}"
```

The profile also exposes `%{project_url}` and `%{analytics_host}` for legal or
service copy. Callers can still override any interpolation explicitly.

## Asset convention

Every key under `brand.assets` is explicit and may be `null`:

| Key | Recommended format and use |
| --- | --- |
| `logo` | Horizontal SVG or PNG for the sidebar and public header |
| `compact_mark` | Square SVG or PNG for compact navigation contexts |
| `email_logo` | Email-safe PNG; SVG is discouraged for mail clients |
| `og_image` | 1200 × 630 PNG or JPEG for social sharing |
| `favicon_ico` | Public `.ico` fallback |
| `favicon_svg` | Public scalable browser icon |
| `favicon_png` | Public 96 × 96 PNG |
| `apple_touch_icon` | Public 180 × 180 PNG |
| `web_manifest` | Public web app manifest |

Names without a leading slash resolve under `app/assets/images` and use the
Rails asset pipeline. Paths beginning with `/` resolve under `public`. Paths
must stay inside those directories and must exist when the application boots.

Missing logo-like assets render the configured short name as accessible text.
Missing favicon, manifest, analytics, and social-image values omit their tags;
they never generate empty URLs.

The minimal profile deliberately sets every asset to `null` and uses a distinct
example palette, proving that a new installation does not inherit the IMASUS
logo, icons, or colours. Add branded files only after copying the profile for
your installation.

## Theme

The profile provides six six-digit hexadecimal colour roles:

- `primary`: main text, actions, outlines, and structural emphasis
- `secondary`: deep supporting surfaces
- `accent`: sparingly used emphasis and destructive affordances
- `success`: positive and highlighted surfaces
- `info`: informational/resource surfaces
- `soft`: low-emphasis supporting surfaces

Rails emits validated CSS custom properties and Tailwind exposes
`brand-primary`, `brand-secondary`, `brand-accent`, `brand-success`,
`brand-info`, and `brand-soft` utilities. Arbitrary CSS is not loaded from a
profile. The IMASUS values match the previous palette exactly.

## Email and analytics

`brand.email` defines the non-secret default sender name and address. Deployments
may override the complete `From` value with `MAILER_FROM`; SMTP credentials stay
in environment variables.

Analytics renders only in production when `operations.analytics.enabled` is
true and `script_url` is present. Set `enabled: false` and `script_url: null` to
remove the external script completely.

Run `bin/site-config` after changing any value. Invalid colours, URLs, email
addresses, missing assets, ERB, and secret-like keys stop boot with an actionable
error.
