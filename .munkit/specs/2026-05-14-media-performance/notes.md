# Notes: 2026-05-14-media-performance

## Baseline Evidence Captured 2026-05-14

Production app: `https://app.imasus.eu`

Branch used for spec writing: `codex/media-performance-spec`

### Production Dataset Snapshot

Captured with:

```bash
flyctl ssh console -a imasus-app -C 'bin/rails runner "puts({materials: Material.count, material_assets: MaterialAsset.count, macros: MaterialAsset.macro.count, microscopies: MaterialAsset.microscopy.count, videos: MaterialAsset.video.count, blobs: ActiveStorage::Blob.count, material_asset_bytes: MaterialAsset.joins(file_attachment: :blob).sum(\"active_storage_blobs.byte_size\"), log_entries: LogEntry.count, log_media_attachments: ActiveStorage::Attachment.where(record_type: \"LogEntry\", name: \"media\").count}.to_json)"'
```

Result:

```json
{
  "materials": 60,
  "material_assets": 148,
  "macros": 35,
  "microscopies": 93,
  "videos": 20,
  "blobs": 521,
  "material_asset_bytes": 503482199,
  "log_entries": 52,
  "log_media_attachments": 16
}
```

### Curl Timing Samples

Command shape:

```bash
for url in https://app.imasus.eu/materials/ https://app.imasus.eu/materials/regenerated-wool https://app.imasus.eu/materials/jingyi-yang-algae-based-bioplastic; do
  echo "$url"
  for i in 1 2 3 4 5; do
    curl -sS -o /dev/null -w "run=$i status=%{http_code} dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total} bytes=%{size_download}\n" "$url"
  done
done
```

`/materials/`:

```text
run=1 status=200 dns=0.134480 connect=0.165273 tls=0.198725 ttfb=2.610613 total=2.918521 bytes=176348
run=2 status=200 dns=0.003796 connect=0.037702 tls=0.095319 ttfb=4.227849 total=4.435306 bytes=176348
run=3 status=200 dns=0.004918 connect=0.099677 tls=0.136285 ttfb=3.768075 total=3.932008 bytes=176348
run=4 status=200 dns=0.005792 connect=0.035459 tls=0.069505 ttfb=4.041814 total=4.177700 bytes=176348
run=5 status=200 dns=0.004443 connect=0.034567 tls=0.073305 ttfb=3.959054 total=4.166481 bytes=176348
```

`/materials/regenerated-wool`:

```text
run=1 status=200 dns=0.010285 connect=0.041985 tls=0.074946 ttfb=0.926405 total=0.998401 bytes=34966
run=2 status=200 dns=0.004540 connect=0.035224 tls=0.070440 ttfb=2.281116 total=2.461800 bytes=34966
run=3 status=200 dns=0.002052 connect=0.032894 tls=0.108801 ttfb=1.028388 total=1.332633 bytes=34966
run=4 status=200 dns=0.012288 connect=0.043115 tls=0.146142 ttfb=1.743108 total=1.803830 bytes=34966
run=5 status=200 dns=0.002291 connect=0.032903 tls=0.067604 ttfb=1.527235 total=1.594254 bytes=34966
```

`/materials/jingyi-yang-algae-based-bioplastic`:

```text
run=1 status=200 dns=0.002966 connect=0.033668 tls=0.066939 ttfb=1.431712 total=1.493469 bytes=34456
run=2 status=200 dns=0.004411 connect=0.035347 tls=0.070554 ttfb=1.750161 total=1.818027 bytes=34456
run=3 status=200 dns=0.003559 connect=0.034806 tls=0.070639 ttfb=1.428966 total=1.493355 bytes=34456
run=4 status=200 dns=0.002798 connect=0.033393 tls=0.067247 ttfb=1.439485 total=1.518491 bytes=34456
run=5 status=200 dns=0.004069 connect=0.033804 tls=0.114401 ttfb=1.837992 total=1.952543 bytes=34456
```

Interpretation:

- `/materials/` has the worst server-side response profile and largest HTML payload.
- Material detail pages vary but still have measurable LCP pressure because visible and hidden gallery media are discoverable in initial markup.

### Initial HTML Media Counts

Downloaded with:

```bash
mkdir -p tmp/perf
curl -sS https://app.imasus.eu/materials/ -o tmp/perf/materials-index.html
curl -sS https://app.imasus.eu/materials/regenerated-wool -o tmp/perf/material-regenerated-wool.html
ruby -e 'files=%w[tmp/perf/materials-index.html tmp/perf/material-regenerated-wool.html]; files.each{|f| s=File.read(f); puts({file:f, bytes:s.bytesize, img_tags:s.scan(/<img\b/).size, video_tags:s.scan(/<video\b/).size, source_tags:s.scan(/<source\b/).size, representation_urls:s.scan(%r{/rails/active_storage/representations/redirect}).size, blob_urls:s.scan(%r{/rails/active_storage/blobs/redirect}).size, lazy_images:s.scan(/loading="lazy"/).size}.inspect)}'
```

Results:

```ruby
{:file=>"tmp/perf/materials-index.html", :bytes=>176348, :img_tags=>45, :video_tags=>0, :source_tags=>0, :representation_urls=>37, :blob_urls=>0, :lazy_images=>37}
{:file=>"tmp/perf/material-regenerated-wool.html", :bytes=>34966, :img_tags=>16, :video_tags=>0, :source_tags=>0, :representation_urls=>8, :blob_urls=>0, :lazy_images=>8}
```

Interpretation:

- `/materials/` initially exposes 37 material card image variant URLs.
- `regenerated-wool` exposes 8 image variant URLs for 4 image assets because it renders both hidden main gallery images and thumbnail images.
- All current material image variants use `loading="lazy"`, including likely above-the-fold/LCP media.

### Lighthouse Samples

Command shape:

```bash
npx --yes lighthouse https://app.imasus.eu/materials/ \
  --quiet \
  --chrome-flags='--headless=new --no-sandbox' \
  --only-categories=performance \
  --output=json \
  --output-path=tmp/perf/lighthouse-materials.json

npx --yes lighthouse https://app.imasus.eu/materials/regenerated-wool \
  --quiet \
  --chrome-flags='--headless=new --no-sandbox' \
  --only-categories=performance \
  --output=json \
  --output-path=tmp/perf/lighthouse-regenerated-wool.json
```

Summary extraction:

```bash
ruby -rjson -e '%w[lighthouse-materials lighthouse-regenerated-wool].each{|name| j=JSON.parse(File.read("tmp/perf/#{name}.json")); a=j["audits"]; puts name; puts({score:j.dig("categories","performance","score"), fcp_ms:a.dig("first-contentful-paint","numericValue")&.round, lcp_ms:a.dig("largest-contentful-paint","numericValue")&.round, speed_index_ms:a.dig("speed-index","numericValue")&.round, tbt_ms:a.dig("total-blocking-time","numericValue")&.round, cls:a.dig("cumulative-layout-shift","numericValue"), transfer_bytes:a.dig("total-byte-weight","numericValue"), requests:a.dig("network-requests","details","items")&.size}.inspect); puts }'
```

Results:

```text
lighthouse-materials
{:score=>0.81, :fcp_ms=>3148, :lcp_ms=>3298, :speed_index_ms=>6318, :tbt_ms=>0, :cls=>0.000963, :transfer_bytes=>523525, :requests=>53}

lighthouse-regenerated-wool
{:score=>0.76, :fcp_ms=>2762, :lcp_ms=>5009, :speed_index_ms=>3303, :tbt_ms=>0, :cls=>0, :transfer_bytes=>534612, :requests=>49}
```

Largest transferred resources on `/materials/` included:

```text
Script  124223  https://app.imasus.eu/assets/trix-be60fa75.js
Image    37264  https://imasus-app-production.fly.storage.tigris.dev/fuvtvwmiqkpmj7g6cvixt6k7amtq
Script   34661  https://app.imasus.eu/assets/turbo.min-9fd88cd5.js
Image    26181  https://imasus-app-production.fly.storage.tigris.dev/ym8z1md50le2x5278bnzkom544lz
Font     23019  https://app.imasus.eu/assets/general-sans-medium-cddeb756.woff2
Image    22324  https://imasus-app-production.fly.storage.tigris.dev/ysurgfv37k4zmnlkmxilif1rhlfd
Image    22306  https://imasus-app-production.fly.storage.tigris.dev/4pjzcxr8wm2lewnmxgxidm1d6sps
Image    21776  https://imasus-app-production.fly.storage.tigris.dev/44mrp3ws277k3fayn5vmy2dg4j0p
Font     21248  https://app.imasus.eu/assets/general-sans-bold-ab099d95.woff2
Image    20680  https://imasus-app-production.fly.storage.tigris.dev/eku0lxdvuqkctz68tur2ir1xoq7l
Image    19669  https://app.imasus.eu/assets/eu-funded-white-1fb669e3.png
Other    18189  https://app.imasus.eu/favicon.svg
```

Interpretation:

- Trix is loaded on `/materials/` even though the catalogue does not need rich-text editing. A JS-loading split may be a useful follow-up within Track 1 if it is easy and low risk.
- Image transfer sizes are individually modest after variants, but many images are discoverable/requestable on initial load.

## Code Path Findings

### Materials Index

- `MaterialsController#index` loads all matching materials and all material asset blobs:
  - `Material.includes(assets: { file_attachment: :blob }).order(:position)`
  - then `@materials = scope.to_a`
- `app/views/materials/index.html.erb` renders every material in one grid.
- `app/views/materials/_card.html.erb` renders `material.cover_asset.file` through `image_variant_tag(..., preset: :card)`.
- `image_variant_tag` currently calls `.processed`, which means template rendering can force variant processing before response completion.

### Material Detail

- `material_gallery_items` returns video, macro, and all microscopy assets.
- `app/views/materials/show.html.erb` renders all full-size gallery images in the main viewer and hides non-active items with `hidden`.
- The same page also renders thumbnail variants for each image.
- Current `<video>` uses `preload="metadata"` when videos are present.

### Log Entries

- `LogEntriesController#index` renders every entry for the project:
  - `@project.log_entries.with_rich_text_body.with_attached_media.includes(:author)`
- `app/views/log_entries/_entry.html.erb` loops through all attached media.
- Images use `attachment.variant(resize_to_limit: [800, 600], format: :jpeg)` directly in the view.
- Videos render a normal `<video controls>` with a direct blob URL source, so browsers may fetch metadata or bytes during initial page load.

## Strategy Chosen With User

The user approved combining:

1. Rails/UI delivery improvements.
2. Media pipeline improvements.

The user explicitly does not want numbered pagination or a visible "load more" primary control. Infinite/progressive loading on scroll is acceptable. The user also explicitly wants video posters and no video loading until click.

## Candidate Implementation Shape

### Progressive Materials Loading

- Use a query object or small PORO if the current `MaterialsController#index` becomes too crowded.
- Keep the first request as normal HTML.
- Add a `page`/`cursor` param for Turbo-driven batch requests.
- Render a first batch sized for first viewport and quick browsing, for example 12 cards.
- Add a sentinel Turbo Frame at the end of the list. When it nears the viewport, request the next batch.
- Preserve filter/search params in the next-batch URL.

### Detail Gallery

- Initial DOM:
  - active hero image
  - thumbnails/posters
  - no hidden full-size image tags for non-active assets
- Thumbnail click:
  - fetch a Turbo Frame or endpoint for selected full-size media
  - replace the active media frame
- Keep no-JS fallback acceptable: thumbnails can be normal links to the asset or to the material page with a selected media param if needed.

### Video Poster Path

Preferred for material videos:

- Add `has_one_attached :poster` to `MaterialAsset`, only meaningful when `kind == "video"`.
- Add/importer task support for poster generation or poster attachment.
- Render poster image with a play button.
- On click, swap in `<video controls autoplay preload="none">` or set the source lazily immediately before play.

For log-entry videos:

- Either generate posters into a dedicated small `VideoPoster` model keyed to `ActiveStorage::Blob`, or add a service that attaches poster blobs through a separate owner model. Do not mutate `ActiveStorage::Blob` schema.
- If that is too large for this slice, implement poster-first for material videos and use a generic video placeholder for log videos while documenting the follow-up.

### Variant Preprocessing

- Convert the current ad hoc variant calls into named helper/preset usage for all media-heavy surfaces.
- Prefer preprocessing/warming common variants:
  - material card
  - material hero/detail
  - material thumbnail
  - log-entry thumbnail
- Add a rake task such as `media:warm_variants` for existing production assets.
- Consider Rails named variants with `preprocessed: true` if model associations can express the presets cleanly.

### JS Split Follow-Up

Lighthouse shows Trix is the largest transferred resource on `/materials/`. This spec can include a low-risk check to stop loading Trix on read-only pages if the app currently bundles it globally. Keep this secondary to media loading unless it is straightforward.

## After-Benchmark Slot

Fill this after implementation with the same commands:

```text
- /materials curl timing table
- representative detail curl timing table
- log-entry timeline curl timing table
- initial HTML media counts
- Lighthouse materials summary
- Lighthouse detail summary
- notes on skipped measurements, if any
```

## Implementation Notes 2026-05-14

- `/materials` now renders the first 12 cards in the initial response and appends later batches through lazy Turbo Frames (`materials_page_N`). Query parameters remain URL-bound and are carried into the next-frame URL.
- Material card media marks only the first first-page image as `loading="eager"` with `fetchpriority="high"`; later cards keep lazy image loading.
- Material detail galleries now render one main media item in the initial viewer. Thumbnail clicks fetch `/materials/:slug/media?key=...` and replace the viewer, so hidden full-size gallery images are not present in the initial DOM.
- Material videos render poster-first. The initial detail HTML contains a play button and poster image, not a `<video>`, `<source>`, or video blob URL. The deferred media endpoint returns the real `<video preload="none">` player after user intent.
- Log-entry timelines now render the first 10 entries and append later entries through lazy Turbo Frames (`log_entries_page_N`). Image attachments use the named `:log_entry_thumbnail` variant. Video attachments render a poster-style play button and fetch the real player through `GET /projects/:project_id/log_entries/:id/media?attachment_id=...`.
- `image_variant_tag` no longer calls `.processed` during template rendering; common variants can be warmed explicitly with `bin/rake material_assets:warm_variants`.
- `MaterialAsset` has a Rails-native `poster` attachment for generated video posters. Existing material videos can be populated with `bin/rake material_assets:generate_video_posters` when `ffmpeg` is available.
- Added `script/benchmark_media_performance`, which records status, bytes, TTFB, total time, HTML media counts, and optional Lighthouse summaries. Unless `BENCHMARK_PATHS` is provided, it tries to discover a project log-entry timeline from the local database and records a skipped reason if that is unavailable. It reports skipped/failed measurements in JSON instead of silently failing.

### Benchmark Script Smoke Output

Command:

```bash
BENCHMARK_BASE_URL=https://app.imasus.eu BENCHMARK_LIGHTHOUSE=0 ruby script/benchmark_media_performance
```

Output captured before deployment of this branch, so it still reflects current production baseline:

```json
{
  "generated_at": "2026-05-14T08:16:41Z",
  "base_url": "https://app.imasus.eu",
  "responses": [
    {
      "url": "https://app.imasus.eu/materials",
      "status": 200,
      "bytes": 176347,
      "ttfb": 2.4021,
      "total_time": 2.4045,
      "counts": {
        "img_tags": 45,
        "video_tags": 0,
        "source_tags": 0,
        "representation_urls": 37,
        "blob_urls": 0,
        "lazy_images": 37
      }
    },
    {
      "url": "https://app.imasus.eu/materials/regenerated-wool",
      "status": 200,
      "bytes": 34966,
      "ttfb": 0.8434,
      "total_time": 0.8457,
      "counts": {
        "img_tags": 16,
        "video_tags": 0,
        "source_tags": 0,
        "representation_urls": 8,
        "blob_urls": 0,
        "lazy_images": 8
      }
    }
  ],
  "lighthouse": {
    "skipped": "disabled"
  }
}
```

### Verification Notes

- Focused Rails tests could not run locally because PostgreSQL is not listening on `/tmp/.s.PGSQL.5432`.
- `ruby -c` passed for changed Ruby controllers, helpers, models, benchmark code, and focused tests.
- Locale YAML parsing passed for `en`, `es`, `it`, and `el`.
- `bin/rails routes -g 'materials|log_entries'` confirms the new deferred media routes.
- `ruby -Itest test/lib/media_performance_benchmark_test.rb` passes because it avoids the Rails DB boot path.
- `bin/rubocop` passed for changed Ruby app/lib/test files.
