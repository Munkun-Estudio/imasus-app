# Initial imagineering workshop foundation

## What

Set up the initial IMASUS App repository as a conventional Rails application with PostgreSQL, the default Rails 8 stack, and the Munkun workflow tooling needed to guide future work. This first slice should establish project context, contribution conventions, and a minimal bootable application surface without locking in domain models or heavy product decisions too early.

## Why

This repository will be public and collaborative, so the foundation needs to be clean, legible, and easy for future contributors to understand. The project also needs enough Munkit context to keep product and architectural choices grounded in the IMASUS mission and the imagineering workshop framing from day one.

## Acceptance Criteria

- [x] A new Rails application exists in the repository root using PostgreSQL and the default Rails 8 stack.
- [x] `munkit` and `munkit-symphony` are installed as project gems and available through the bundle.
- [x] The repo contains an initialized Munkit workspace with a filled first-pass memory, context, and active spec.
- [x] The repository includes a contributor-facing README and contribution guidance appropriate for a public project.
- [x] The application has a minimal root page and at least one automated test covering it.

## Out of Scope

- Authentication and authorization
- Workshop domain models and persistence design
- Production deployment configuration beyond the Rails defaults already generated
- Final visual design system and brand assets
- Final license selection

## Notes

- Project site: https://imasus.eu/
- Imagineering interview and framing: https://imasus.eu/blog/imagineering-expert-diane-nijs-interview/
