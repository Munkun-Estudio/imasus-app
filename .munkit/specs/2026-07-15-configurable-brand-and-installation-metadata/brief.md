# Configurable brand and installation metadata

## What

Move installation identity and presentation into configuration: product name,
organisation, logos, favicons, metadata, public/support/legal links, email
identity, analytics opt-in, and a small semantic theme. Preserve the existing
IMASUS appearance as the reference implementation.

## Why

The current name, assets, colour utilities, footer, mail copy, metadata, and
service identifiers are embedded throughout the application. A clone cannot be
credibly rebranded without editing code and finding hidden references.

## Acceptance Criteria


- [ ] Layouts, navigation, footer, authentication, mailers, metadata, and legal
  surfaces use configured installation identity and assets.
- [ ] A documented asset convention supports a logo, compact mark, favicon, and
  email-safe variant, including accessible text fallbacks.
- [ ] User-facing colours are expressed through a bounded set of semantic theme
  tokens; the IMASUS profile renders the current palette.
- [ ] Analytics and other optional external identifiers are disabled when absent
  and do not emit invalid markup or requests.
- [ ] A repository search and automated checks show no unintended IMASUS product
  copy or domains remain in reusable application code.
- [ ] Branding configuration has request/view coverage for configured and missing
  optional values.

## Out of Scope


- A visual theme builder or arbitrary user-supplied CSS.
- General redesign of the current interface.

## Notes

Depends on `Application configuration foundation`. Deployment resource names may
remain profile-specific, but reusable templates and documentation must not assume
the IMASUS domain.
