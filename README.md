# IMASUS App

IMASUS App is a configurable Rails platform for collaborative workshops. An
organisation can provide its own identity, languages, resource modules,
workshops, guides, library, prompts, and glossary through checked-in profiles
and content manifests without changing shared application code.

The application originated in the [IMASUS project](https://imasus.eu/), where
participants use an imagineering approach inspired by
[Diane Nijs](https://imasus.eu/blog/imagineering-expert-diane-nijs-interview/)
to explore sustainable material futures. The `imasus` profile preserves that
public installation while `minimal` provides a neutral adoption example.

## Origin and stewardship

Munkun SL conceived the original IMASUS project in 2023, wrote the project
proposal, led the product and experience design, and designed and developed this
software platform. Munkun SL remains the author and steward of the open-source
application, with [Pablo Jimeno Pérez](https://orcid.org/0009-0002-0588-7715)
and [Guillermo Orduña](https://orcid.org/0009-0001-0114-6138) named as its
principal creators.

The materials research was carried out by the Institute of Nanoscience and
Materials of Aragón (INMA). The research underpinning the training modules and
challenges was carried out by Lottozero. The work was developed through the
EU-funded IMASUS project under Erasmus+ grant
`2024-1-ES01-KA220-VET-000257495`.

See [Credits](CREDITS.md) for the project provenance and contribution record,
the [IMASUS website](https://imasus.eu/), and the project's
[results](https://imasus.eu/results/).

## Status

Version 1.0.0 is the first stable release of the configurable application
foundation. The repository includes:

- a complete workshop, project, process-log, and publication workflow;
- selectable installation profiles and optional resource modules;
- profile-owned multilingual content for Guides, Library, Prompts, and Glossary;
- an IMASUS compatibility profile and a deliberately neutral minimal profile.

## Stack

- Ruby 3.4
- Rails 8.1
- PostgreSQL
- Hotwire with Importmap
- Solid Queue, Solid Cache, and Solid Cable

## Getting Started

```bash
bundle install
APP_PROFILE=minimal bin/site-config
APP_PROFILE=minimal bin/setup --skip-server
APP_PROFILE=minimal bin/dev
```

The default Rails health endpoint is available at `/up`.

See [Adopt the application](docs/adoption.md) for the complete clone,
customisation, content, validation, and production-readiness walkthrough.
See [Deployment](docs/deployment.md) for the European Scaleway reference
architecture.

## Installation Profile

The application currently boots with the checked-in `imasus` profile. Validate
the active profile with:

```bash
bin/site-config
```

See [Installation configuration](docs/configuration.md) for the versioned
contract, profile selection, validation rules, and secret-handling policy. See
[Adopt the application](docs/adoption.md) for the shortest path from the neutral
example to a new installation. See
[Branding an installation](docs/branding.md) for logos, favicons, metadata,
localized identity placeholders, email defaults, and semantic theme roles.
See [Guide content](docs/guides.md) for the manifest and folder convention used
to add localized Guides without changing application code.
See [Library content](docs/library.md) for reusable resource types, presentation
hints, taxonomies, media conventions, and the reviewable sync workflow.
See [Prompt and glossary catalogues](docs/catalogs.md) for stable IDs,
localized categories, publication and the database synchronization workflow.

## Development Workflow

Before making non-trivial changes:

1. Read [AGENTS.md](AGENTS.md).
2. Add or update tests for shared behaviour.
3. Update the relevant public documentation when you introduce durable project
   knowledge.

Repository conventions:

- Prefer Rails defaults and common libraries before adding new dependencies.
- Keep branches short-lived and descriptive.
- Use conventional commits when possible.
- Open small PRs with clear validation notes.

## Key Commands

```bash
bin/rails test
bin/ci
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and collaboration expectations.

## Citation

If you use this software in research, education, or another project, please use
the metadata in [CITATION.cff](CITATION.cff). A DOI will be added after the
software has been archived in Zenodo.

## License

The original software in this repository is licensed under the [MIT License](LICENSE), Copyright (c) 2026 Munkun SL.

The MIT License does not apply automatically to installation content, uploaded or bundled media, project names, logos, or trademarks. Those assets retain their stated licences and ownership; when no separate licence is stated, no additional rights are granted.

Third-party code or content must retain its own licence and attribution.
