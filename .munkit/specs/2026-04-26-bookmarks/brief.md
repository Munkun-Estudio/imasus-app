# Bookmarks

## What

A personal save-for-later system for authenticated users. Two flavours:

- **Page-level bookmarks** — one bookmark per Material, Glossary Term, or Challenge. A toggle icon on the resource saves or removes it.
- **Anchor-level bookmarks** — inside any Training Module section, a hover-reveal bookmark icon sits beside every heading and paragraph block. Clicking saves the specific passage. Inspired by GitHub's heading-anchor links.

Bookmarks surface on a dedicated `/bookmarks` page (grouped by type), in a "Your bookmarks" strip on the Home page (most recent 6), and via a Bookmarks link in the User menu.

## Why

Participants read through dense training content and material descriptions across multiple sessions. They currently have no way to mark passages to return to. Bookmarks turn passive reading into a navigable personal library, and give the Home page a personalised anchor without requiring a recommendation engine.

## Acceptance Criteria

### Model & data

- [ ] A `Bookmark` record stores who saved it, what type of resource, a stable key, a display label, and a URL to return to.
- [ ] A user cannot have duplicate bookmarks for the same resource/anchor.
- [ ] Deleting a user deletes all their bookmarks.

### Routing & auth

- [ ] `GET /bookmarks` — authenticated users only.
- [ ] `POST /bookmarks` — authenticated users only; duplicate submissions are ignored.
- [ ] `DELETE /bookmarks/:id` — authenticated users only; users can only delete their own bookmarks.
- [ ] Unauthenticated requests to any bookmarks route are rejected.

### Bookmark toggle — Materials and Glossary Terms

- [ ] A bookmark toggle icon appears in the show-page header for Materials and Glossary Terms.
- [ ] The icon reflects the saved/unsaved state without a full page reload.
- [ ] Clicking the icon saves or removes the bookmark and updates the icon in place.
- [ ] Guests see no bookmark icon.

### Bookmark toggle — Challenges

- [ ] Each challenge card on the `/challenges` index gains a bookmark icon.
- [ ] Clicking it saves or removes that challenge as a bookmark.
- [ ] The card updates in place (no page reload).
- [ ] Guests see no icon.

### Bookmark toggle — Training Module anchors

- [ ] Every heading (`h2`–`h4`) and paragraph in a training module section displays a bookmark icon on hover, to the left of the content.
- [ ] The icon is coloured when that passage is already bookmarked.
- [ ] Clicking saves the passage (including which module, section, locale, and anchor) or removes it if already saved.
- [ ] The label saved is the heading text, or the first ~100 characters of a paragraph.
- [ ] The saved URL links back to that exact section and scrolls to the anchor.
- [ ] Guests see no icons.

### Bookmarks index (`/bookmarks`)

- [ ] Bookmarks are grouped into four sections: Training, Materials, Glossary, Challenges.
- [ ] Each entry shows its label, a contextual subtitle, and a link to the saved URL.
- [ ] Each entry can be deleted inline without a page reload.
- [ ] Each group shows an empty state with a link to browse that resource area when it has no bookmarks.
- [ ] Bookmarks are sorted newest-first within each group.

### Home page

- [ ] Authenticated users with at least one bookmark see a "Your bookmarks" section on the home page showing the most recent 6, with a "See all" link to `/bookmarks`.
- [ ] The section is hidden entirely when the user has no bookmarks.

### User menu

- [ ] The user menu flyout has a Bookmarks link to `/bookmarks`.

### i18n

- [ ] All new user-facing strings have keys in all four locale files (en, es, it, el).

## Out of Scope

- Bookmarking Workshop pages.
- Shared or public bookmark lists.
- Bookmark folders or tags.
- Sidebar nav entry — surfaced via User menu and Home only, to preserve the identical-sidebar-for-all-roles rule.
- Email digests or notifications about bookmarks.
- Reordering bookmarks.
