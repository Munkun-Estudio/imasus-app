# Contributing

Thanks for contributing to IMASUS App.

## Setup

```bash
bundle install
bin/setup
bin/rails db:prepare
bin/dev
```

## Working Agreement

- Prefer Rails conventions and existing dependencies before proposing new libraries.
- For non-trivial work, start from the active Munkit spec or create a new one.
- Keep branches short-lived and descriptive, for example `feature/workshop-intake` or `fix/root-layout`.
- Prefer conventional commits when practical.
- Keep PRs focused and easy to review.

## Before Opening a PR

- Run the relevant tests locally.
- Run `bin/ci` when the change touches multiple layers or shared behavior.
- Update `.munkit/MEMORY.md`, `.munkit/DECISIONS.md`, or the active spec when you discover durable project knowledge.
- Explain what changed, how you validated it, and what is still pending.

## Public Repo Note

This repository is public. Avoid introducing dependencies or workflows that require private registry access unless the team explicitly approves that tradeoff.

## License

The project license is still pending. Do not add or change licensing files without maintainer approval.
