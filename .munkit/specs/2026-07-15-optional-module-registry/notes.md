# Notes: 2026-07-15-optional-module-registry

## Initial discovery

- `ApplicationHelper#primary_navigation_items` and
  `shared/_resources_grid.html.erb` hardcode Materials, Training, Challenges, and
  Glossary.
- `Bookmark::BOOKMARKABLE_TYPES`, `BookmarksController::GROUPED_TYPES`, and
  `BookmarksHelper::BOOKMARK_DOT_COLORS` repeat the same resource set.
- All module routes are unconditional in `config/routes.rb`; disabled-module
  semantics need to be consistent at routing/controller and authorization layers.

## Implemented design

- `ResourceModuleRegistry` combines stable internal keys with profile-controlled
  enabled state and localized labels. Definitions declare legacy route helpers,
  controllers, content sources, bookmark types/previews, navigation metadata,
  and dependency lists.
- Supported resource routes remain defined. `MaterialsController`,
  `TrainingController`, `ChallengesController`, and
  `GlossaryTermsController` return 404 before loading content when disabled.
- Sidebar navigation and home resource cards iterate enabled registry entries.
- Bookmark validation, creation, grouping, recent lists, labels, colours, and
  preview behaviour derive from registry metadata. Disabled bookmark types are
  rejected without deleting stored bookmarks.
- Cross-module integrations degrade safely: glossary highlighting becomes a
  no-op and the optional project challenge/prompt selector and cards disappear.
- Registry dependency validation runs at application preparation/boot.
- `config/profiles/minimal.yml` is the executable one-locale, Guides-only
  example; `docs/modules.md` documents the contract and compatibility model.

## Verification

- Minimal-profile subprocess smoke test verifies the enabled Guides UI/route,
  404s for Library, Prompts, and Glossary, an unaffected Workshops endpoint,
  accepted Guides bookmarks, and rejected Library bookmarks.
- `rails test`: 865 runs, 3,777 assertions, no failures.
- `rails test:system`: 22 runs, 140 assertions, no failures.
- RuboCop: 209 Ruby files, no offenses.
- Brakeman: zero security warnings.
- IMASUS test seed replant completed successfully.
