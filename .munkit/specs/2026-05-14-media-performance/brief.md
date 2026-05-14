# Media performance

## What

Improve the perceived and measured performance of media-heavy surfaces without making the catalogue feel paginated or fragmented. The first slice covers the public materials index, material detail pages, and project log-entry timelines. It combines Rails/UI delivery improvements with a media pipeline pass:

- Progressive, scroll-triggered loading for the materials catalogue instead of rendering every material card in the initial response.
- First-viewport image prioritisation and offscreen image deferral.
- Video poster generation and click-to-load playback so video files are not requested until a user explicitly plays them.
- Preprocessed image variants for high-traffic material and log-entry sizes so visitors do not pay synchronous variant-processing costs.
- A repeatable benchmark task/script that records before/after evidence for the performance-sensitive pages.

This is a performance and UX slice, not a visual redesign. The catalogue should still feel like one continuous exploratory surface, and media should feel calmer and more intentional.

## Why

The materials database is now backed by real production media. Production currently has 60 materials, 148 material assets, 20 videos, and roughly 503 MB of material asset blobs. The `/materials/` page renders every material card in one HTML response, with 37 Active Storage representation URLs in the initial document. Representative production measurements from 2026-05-14 showed:

- `/materials/`: 176 KB HTML, 53 Lighthouse network requests, roughly 524 KB transfer, Lighthouse performance score `0.81`, LCP around `3.3s`, Speed Index around `6.3s`, and repeated raw HTML TTFB samples often around `3.8s-4.2s`.
- `/materials/regenerated-wool`: 35 KB HTML, 8 image variant URLs for 4 media assets because hidden full-size gallery images and thumbnails are all in the initial DOM, Lighthouse performance score `0.76`, LCP around `5.0s`.

The app is used in workshops, where participants may browse media-rich materials and log entries on shared or mixed-quality networks. The experience should prioritise fast orientation, fast first content, and intentional media loading over eager completeness.

## Acceptance Criteria

### Benchmarking

- [ ] Add a repeatable benchmark entry point, runnable from the project root, that measures at least:
  - `GET /materials`
  - one representative material detail page with multiple images
  - one project log-entry timeline with attached media
  - optionally one filtered `/materials?...` URL when useful
- [ ] The benchmark records:
  - HTTP status, response bytes, TTFB, total time
  - initial HTML counts for `<img>`, `<video>`, `<source>`, Active Storage representation URLs, and Active Storage blob URLs
  - Lighthouse performance metrics for `/materials` and the representative detail page when Chrome/Lighthouse is available
  - production dataset counts relevant to media volume when production credentials are available
- [ ] Store the initial benchmark output in this spec's `notes.md` and update it with after numbers before the implementation PR is considered complete.
- [ ] The benchmark must degrade gracefully when production access, Chrome, or Lighthouse is unavailable: record which measurements were skipped rather than failing silently.

### Materials Index

- [ ] Keep `/materials` as a continuous browse surface. Do not add numbered pagination or a visible "load more" button as the primary interaction.
- [ ] Render only the first batch of material cards in the initial HTML response.
- [ ] Load subsequent batches automatically as the user scrolls near the end of the rendered list, using Turbo Frames/Streams and a small Stimulus controller or an equivalent Hotwire-friendly pattern.
- [ ] Preserve existing filter/search semantics:
  - URL-bound query parameters remain shareable.
  - Back/forward navigation continues to work.
  - Unknown chip values are ignored.
  - Within-facet OR and cross-facet AND behaviour stays unchanged.
- [ ] Preserve accessibility:
  - Newly loaded cards are inserted into the list without stealing focus.
  - A screen-reader-accessible status announces that more materials were loaded.
  - Keyboard users can reach every loaded card and preview affordance.
- [ ] First-viewport card images should be discoverable and prioritised for LCP: do not mark likely first-viewport/LCP images as lazy, and use `fetchpriority="high"` only on the highest-impact image(s).
- [ ] Offscreen card images remain lazy-loaded and should not compete with first-viewport media.
- [ ] The initial `/materials` HTML should contain materially fewer material card image URLs than the baseline 37 representation URLs.

### Material Detail Pages

- [ ] Avoid rendering every hidden full-size gallery image in the initial DOM.
- [ ] Render the active gallery media plus lightweight thumbnails/posters initially.
- [ ] When a user selects a gallery thumbnail, fetch or reveal the full media intentionally without loading every full-size representation up front.
- [ ] The main hero/LCP image should not be lazy-loaded when it is visible above the fold. Use eager loading and `fetchpriority="high"` where appropriate.
- [ ] Thumbnail images remain small and lazy where they are below the fold.
- [ ] Detail pages with video assets render a poster-first player that does not request the video file until the user clicks play.
- [ ] Detail-page benchmark output should show a lower initial full-size representation count than the baseline where pages currently render hidden full-size images.

### Log Entries

- [ ] Add media rendering rules for process-log timelines:
  - Images render as bounded thumbnails first, not full original files.
  - Videos render as poster-first controls and do not load video bytes until user intent.
  - Long timelines do not render every media-heavy entry in the initial response.
- [ ] Apply scroll-triggered loading or another continuous-loading pattern to log-entry timelines when a project has enough entries to matter.
- [ ] Preserve project visibility and edit/delete authorisation rules.
- [ ] Preserve Action Text rendering and attachment validation behaviour.

### Media Pipeline

- [ ] Define a small named variant set for current surfaces, covering at least:
  - material card
  - material detail hero
  - material thumbnail
  - log-entry thumbnail
  - optional low-quality/blur placeholder if the implementation chooses progressive image reveal
- [ ] Preprocess high-traffic variants on upload/import or via a repeatable warmup task so normal page rendering does not synchronously process common variants.
- [ ] Add a repeatable poster-generation path for material videos and log-entry videos.
- [ ] Store poster files in a Rails-native way that keeps ownership clear. Preferred direction: an explicit Active Storage attachment on the owning media record where the domain model has one (`MaterialAsset`), and a small service/task for log-entry attachments if log posters need a different shape.
- [ ] Video tags use `preload="none"` or an equivalent click-to-load pattern unless the user has already asked to play the video.
- [ ] Do not introduce a third-party image/video SaaS in this slice.
- [ ] If switching Active Storage variant processing from MiniMagick/ImageMagick to libvips is selected during implementation, record the deployment dependency in `DECISIONS.md` and verify the Fly image includes the required system package.

### Caching and Delivery

- [ ] Add fragment caching only where it is easy to invalidate from existing model timestamps or attachment changes.
- [ ] Cache material cards and stable media chrome if it meaningfully reduces server render time.
- [ ] Do not implement a full CDN/edge-hosting migration in this spec. Capture it as a follow-up option after the Rails/UI and pipeline improvements are measured.

### Tests

- [ ] Request tests cover first-batch rendering and subsequent batch loading for `/materials`.
- [ ] Request or system tests cover filter/search URLs with progressive loading.
- [ ] System tests cover scroll-triggered loading enough to prove the user can reach later cards without a visible pagination control.
- [ ] Tests cover material detail pages not rendering every full-size hidden gallery representation initially.
- [ ] Tests cover video poster-first rendering and confirm video URLs are not present in initial markup where the page should defer video loading.
- [ ] Log-entry tests cover thumbnail/poster rendering without changing visibility rules.
- [ ] The benchmark script/task has a focused test for output shape when feasible, or a documented smoke command if it depends on external network/Chrome.

### Documentation

- [ ] Update this spec's `notes.md` with before/after benchmark numbers.
- [ ] Update `.munkit/MEMORY.md` if a durable pattern emerges, for example "media-heavy pages use poster-first video and scroll-triggered batches."
- [ ] Record an architectural decision only if the implementation introduces a durable infrastructure or processing choice, such as libvips or generated video poster storage.

## Out of Scope

- Numbered pagination or a visible "Load more" primary control for the materials catalogue.
- A full CDN migration or custom asset host strategy.
- Replacing Active Storage with another media service.
- Curator CRUD changes.
- Search ranking, full-text search, or new material taxonomy.
- Visual redesign of the materials catalogue, detail gallery, or process log.
- Background job dashboarding beyond what is needed for variant/poster processing.

## Notes

- Current official performance guidance says likely LCP images should not be lazy-loaded and can benefit from appropriate fetch priority. See:
  - https://web.dev/articles/optimize-lcp
  - https://web.dev/articles/browser-level-image-lazy-loading
  - https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/fetchpriority
- Rails Active Storage variants are lazily transformed on request unless preprocessed or warmed. Rails documentation also notes libvips can be much faster and lower-memory than ImageMagick for image transformations, but that choice carries deployment dependencies:
  - https://guides.rubyonrails.org/active_storage_overview.html
