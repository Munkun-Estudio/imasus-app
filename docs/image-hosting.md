# Image Hosting Strategy

This project uses **AWS S3 via Active Storage** for image and media storage in production.

## Decision

- Storage backend: S3 via Active Storage
- URL mode: `rails_storage_proxy`
- Variant processor: `mini_magick`
- CDN direction: CloudFront in front of the Rails app or the Active Storage proxy endpoints

This keeps the storage layer Rails-native and aligned with the existing AWS relationship in IMASUS, while producing cacheable proxy URLs that can sit behind a CDN later without changing application code.

## Why This Shape

### Chosen path

S3 + Active Storage + proxy URLs is the simplest durable baseline:

- it uses Rails primitives instead of adding a dedicated image service now
- it keeps image attachments and variants in one place
- it allows CloudFront to cache image responses at the edge once deployment wiring is added

### Options considered

- **S3 + CloudFront + Active Storage variants**
  - Pros: Rails-native, no extra service, fits current AWS usage
  - Cons: first-request variant generation happens in the app process
- **S3 + imgproxy**
  - Pros: faster on-the-fly transforms, strong CDN story
  - Cons: extra infrastructure and operational surface
- **Managed image service such as Cloudflare Images**
  - Pros: low ops, fast transforms
  - Cons: extra vendor dependency and a less Rails-native data flow

## Variant Presets

The reusable presets live in `ImageVariants`:

- `thumbnail`: `200x200`
- `card`: `400x300`
- `detail`: `1200x1200`
- `hero`: `1600x900`

The app currently keeps the Rails default format behavior: resize the source image without introducing WebP or AVIF conversion yet.

## Performance Defaults

- Render images through `image_variant_tag(...)`
- Use `loading="lazy"` by default
- Always include explicit `width` and `height`
- Keep originals in S3; generate variants lazily on first request

## Production Configuration

Set these environment variables:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `AWS_S3_BUCKET`

`config/storage.yml` points production at the `amazon` service, while development and test continue using local/test disk storage.

## Local And CI Requirements

The current processor choice is `mini_magick`, so environments that run variant generation need ImageMagick available.

- macOS: `brew install imagemagick`
- Ubuntu CI: install `imagemagick` before running the test suite
