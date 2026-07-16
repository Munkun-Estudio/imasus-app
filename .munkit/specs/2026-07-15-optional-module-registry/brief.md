# Optional module registry

## What

Define a registry for installation-selectable resource modules and use it to
enable or disable Glossary, Library (current Materials), Guides (current
Training), and Prompts (current Challenges) consistently across the application.

## Why

The current resource navigation, home page, routes, bookmarks, authorization,
and facilitator surfaces assume every IMASUS tool exists. A reusable installation
needs one source of truth for the tools it exposes.

## Acceptance Criteria


- [ ] Each supported module declares a stable key, configured label, route/helper
  metadata, content source, bookmark capability, and availability state.
- [ ] Navigation, home/resources surfaces, search or linking surfaces, and
  bookmarks derive module choices from the registry rather than hardcoded lists.
- [ ] Disabled modules are absent from the UI and their direct endpoints fail
  safely without affecting core workshop/project workflows.
- [ ] Module combinations are validated, including dependencies between modules
  or content field types.
- [ ] The all-enabled IMASUS profile and a documented minimal profile pass request,
  authorization, and system-level tests.
- [ ] Adding a supported module instance requires configuration and content, not
  edits to shared navigation or bookmark conditionals.

## Out of Scope


- Dynamically loading third-party Ruby or JavaScript code.
- Making workshops, projects, memberships, logs, or publication optional in v1.

## Notes

Depends on `Application configuration foundation`; locale-aware labels also depend
on `Configurable locales and localized rich text`.
