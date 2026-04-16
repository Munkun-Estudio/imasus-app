# App Shell and Navigation — Notes

Implementation notes, discoveries, and scratch space. Update as work progresses.

## References

- Mockup `AppShell.tsx`, `VerticalNav.tsx`, `Footer.tsx` in `/Users/pablo/projects/imasus_app_mockup/src/components/`
- Mockup `tailwind.config.js` for palette token names
- Brand palette from design brief: Dark Green #1F3D3F, Navy #252645, Red #FA3449, Mint #AFE0C7, Light Blue #AFCEDE, Light Pink #FFC2D7
- Font: General Sans (source TBD — check if available via Fontsource, Google Fonts, or self-hosted)

## EU Funding Notice

Mockup footer text: "Imagineering Sustainable Fashion is an EU-funded educational project developing innovative…" and "© 2024-2026 IMASUS Project. Funded by the European Union." — verify against the Bridgetown site for the exact legal wording and any required EU disclaimer.

## Partner Logos

Source candidates: mockup repo `public/logo.svg`, Bridgetown site assets. Need logos for CSIC, Lottozero, ECHN, Munkun.

## Decisions Made

- Mobile nav: hamburger menu with overlay sidebar (not horizontal tabs).
- Locale strategy: `?locale=` param + cookie persistence + `around_action`. No subdomain routing.

## Open Questions

- Font hosting: General Sans is not on Google Fonts. Options: self-host from assets, use Fontsource npm package via Importmap, or fall back to a similar available font. Decide during implementation.
- Exact EU legal disclaimer text — needs verification against the official Erasmus+ co-funding notice requirements.
