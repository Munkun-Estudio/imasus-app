# Notes: 2026-07-15-optional-module-registry

## Initial discovery

- `ApplicationHelper#primary_navigation_items` and
  `shared/_resources_grid.html.erb` hardcode Materials, Training, Challenges, and
  Glossary.
- `Bookmark::BOOKMARKABLE_TYPES`, `BookmarksController::GROUPED_TYPES`, and
  `BookmarksHelper::BOOKMARK_DOT_COLORS` repeat the same resource set.
- All module routes are unconditional in `config/routes.rb`; disabled-module
  semantics need to be consistent at routing/controller and authorization layers.

## Open questions

- Prefer stable internal module keys (`library`, `guides`, `prompts`, `glossary`)
  while preserving legacy route helpers through aliases or redirects.
- Determine whether routes should be omitted at boot or kept with a uniform 404;
  testability and URL compatibility should drive the decision.
