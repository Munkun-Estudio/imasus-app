# IMASUS App

IMASUS App is the Rails application for the [IMASUS project](https://imasus.eu/). It is being built as an open-source tool for students participating in IMASUS workshops, where they will use an imagineering approach inspired by [Diane Nijs](https://imasus.eu/blog/imagineering-expert-diane-nijs-interview/) to explore and develop responses to large social and systemic challenges.

## Status

This repository currently contains the project foundation:

- Rails 8 application scaffolded with PostgreSQL and the default Hotwire stack
- Munkit workspace and Symphony workflow scaffolding
- Public-repo setup documents for contribution and review hygiene
- A minimal landing page while the workshop product is defined

## Stack

- Ruby 3.4
- Rails 8.1
- PostgreSQL
- Hotwire with Importmap
- Solid Queue, Solid Cache, and Solid Cable
- Munkit and Munkit Symphony for project context and orchestration

## Getting Started

```bash
bundle install
bin/setup
bin/rails db:prepare
bin/dev
```

The default Rails health endpoint is available at `/up`.

## Development Workflow

Before making non-trivial changes:

1. Read [AGENTS.md](/Users/pablo/projects/imasus-app/AGENTS.md).
2. Review the active spec under [.munkit/specs](/Users/pablo/projects/imasus-app/.munkit/specs).
3. Update Munkit memory or decisions when you introduce durable project knowledge.

Repository conventions:

- Prefer Rails defaults and common libraries before adding new dependencies.
- Keep branches short-lived and descriptive.
- Use conventional commits when possible.
- Open small PRs with clear validation notes.

## Key Commands

```bash
bin/munkit status
bin/symphony --help
bin/rails test
bin/ci
```

## Contributing

See [CONTRIBUTING.md](/Users/pablo/projects/imasus-app/CONTRIBUTING.md) for setup and collaboration expectations.

## Credits

Agent skill definitions under `.munkit/skills/` are adapted from [igmarin/rails-agent-skills](https://github.com/igmarin/rails-agent-skills) (MIT-licensed, Copyright (c) 2026 Ismael G Marin C). They have been translated to Minitest, pruned to the skills relevant to this project, and rewritten to fit the Munkit-based workflow used here. Upstream attribution, the derivation commit, and a summary of modifications are in [NOTICE](NOTICE).

## License

License selection is still pending. Do not add a license file until the project owners choose one.

The `NOTICE` file tracks attribution for third-party material included in this repository, independently of the project's own license.
