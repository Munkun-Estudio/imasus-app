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
- Describe non-trivial changes in an issue or pull request before implementation
  when the expected behaviour or compatibility boundary is not obvious.
- Keep branches short-lived and descriptive, for example `feature/workshop-intake` or `fix/root-layout`.
- Prefer conventional commits when practical.
- Keep PRs focused and easy to review.

## Parallel Worktrees

- Use one branch per worktree.
- Keep each worktree focused on one discrete slice of work.
- Avoid editing the same files concurrently across worktrees.
- Re-sync from `main` before starting a new slice and after another worktree lands changes you depend on.
- Update the relevant public documentation when a change introduces a durable
  configuration, compatibility, or operational constraint.

## Before Opening a PR

- Run the relevant tests locally.
- Run `bin/ci` when the change touches multiple layers or shared behavior.
- Update README or the relevant file under `docs/` when you discover durable
  project knowledge.
- Explain what changed, how you validated it, and what is still pending.

## Public Repo Note

This repository is public. Avoid introducing dependencies or workflows that require private registry access unless the team explicitly approves that tradeoff.

## License

By contributing original software to this repository, you agree that it may be
distributed under the project's [MIT License](LICENSE). Do not add third-party
code, content, media, logos, or trademarks unless their licence and attribution
are compatible and documented alongside the contribution.
