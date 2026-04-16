# Image Hosting Strategy

## What

Make an architecture decision and implement the Active Storage configuration for image and media hosting across the app. This covers: S3 bucket setup, Active Storage service configuration, image variant pipeline (resizing, format conversion, lazy loading), and a CDN strategy for serving optimised images at scale.

This is a **decision + infrastructure spec**, not a feature spec. It produces configuration, a proof-of-concept upload/display cycle, and documentation — not a user-facing feature.

## Why

Images are central to at least four features: materials (professional photos + micrographs), log entries (student photos/videos), project publication (hero images), and user profiles. The materials database alone will carry a large set of micrographs with SEM metadata.

Making this decision early avoids:

- Retrofitting Active Storage configuration across multiple features.
- Discovering performance problems (large unoptimised images, missing CDN, no lazy loading) after content is already seeded.
- Inconsistent image handling patterns across specs 4, 11, and 12.

The project already uses AWS for the IMASUS newsletter, so S3 is the natural storage backend. The open question is the CDN / image optimisation layer.

## Acceptance Criteria

### Decision

- [ ] A `DECISIONS.md` entry records the chosen architecture: storage backend, CDN, image processing library, and variant strategy.
- [ ] The decision considers and documents trade-offs between at least two CDN/optimisation options (e.g., CloudFront + Active Storage variants vs. imgproxy vs. Cloudflare Images).
- [ ] Cost, complexity, and Rails-native compatibility are weighed explicitly.

### Configuration

- [ ] `config/storage.yml` is configured with an S3 service for production (bucket, region, credentials via Rails credentials or env).
- [ ] Development uses the local disk service (Rails default). Test uses the test service (Rails default).
- [ ] Active Storage is installed and configured (`rails active_storage:install` if not already run).
- [ ] Image processing library is configured: `image_processing` gem with either `vips` (preferred for performance) or `mini_magick` as the backend. Choice documented.

### Variant Pipeline

- [ ] A set of standard image variants is defined and documented (e.g., `thumbnail`, `card`, `detail`, `hero`). Each has a target size, format, and quality.
- [ ] Variants are generated lazily (on first request) and cached by the CDN / Active Storage.
- [ ] Image format: use the Rails default (JPEG/PNG passthrough with resize). WebP or AVIF conversion is a future optimisation, not a requirement for this spec.

### Proof of Concept

- [ ] A test (not a throwaway model or scaffold) demonstrates the pipeline end-to-end: attach an image fixture via Active Storage, generate a variant, and assert the variant URL is present. This can be a standalone integration test with a test-only attachment, or it can use the Material model if spec 4 is in progress.
- [ ] The standard variants are defined as a reusable concern (e.g., `ImageVariants`) that any model with images can include.

### Performance

- [ ] Images in views use `loading="lazy"` and appropriate `width`/`height` attributes or aspect-ratio CSS to prevent layout shift.
- [ ] A documented approach exists for serving images through a CDN (CloudFront, Cloudflare, or the chosen solution). This can be a configuration guide rather than a deployed CDN — deployment is a separate concern.

## Out of Scope

- Actual CDN deployment and DNS configuration (that's deployment ops, not app architecture).
- Video hosting strategy (video is lower priority and may use a different pipeline — e.g., direct S3 links or a video-specific service).
- Material seed data and the full materials feature (spec 4).
- SEM metadata display (spec 4 — the image model here only needs to prove the attachment pipeline works).

## Options to Evaluate

### Option A: S3 + CloudFront + Active Storage variants

- **How:** S3 stores originals. Active Storage generates variants (via `image_processing` gem) on first request. CloudFront sits in front of S3 and caches variant URLs.
- **Pros:** Fully Rails-native. No external image service. CloudFront is in the same AWS ecosystem.
- **Cons:** Variant generation happens in the Rails process (CPU cost on first request). Need to configure CloudFront separately.

### Option B: S3 + imgproxy

- **How:** S3 stores originals. imgproxy (self-hosted or cloud) generates variants on-the-fly from a URL-based API. No Active Storage variants needed.
- **Pros:** Very fast (libvips under the hood). Offloads image processing from Rails. URL-based, so CDN-friendly.
- **Cons:** Extra infrastructure to deploy and maintain. Less Rails-native.

### Option C: S3 + Cloudflare Images (or similar managed service)

- **How:** Upload to Cloudflare Images (or Imgix, Thumbor Cloud). Variants are defined as URL transforms.
- **Pros:** Zero infrastructure. Fast. Managed.
- **Cons:** Additional cost per image. Vendor lock-in. Less control.

### Recommendation (to validate)

Start with **Option A** (S3 + CloudFront + Active Storage variants) because it's fully Rails-native, uses the existing AWS relationship, and avoids extra infrastructure. If performance becomes an issue with the large micrograph set, imgproxy can be added later as a drop-in variant processor without changing the storage layer.

## Implementation Notes

- Check if `image_processing` and `ruby-vips` are already in the Gemfile (Rails 8 includes them by default in new apps).
- The standard variants should be defined as a concern or helper that any model with images can include, so materials, log entries, and projects all use the same sizes.
- For the proof of concept, attaching an image to a temporary scaffold or to the existing home page is sufficient. The test does not need a real S3 upload — Active Storage's test service handles this.
