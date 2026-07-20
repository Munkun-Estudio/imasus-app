# Image Hosting Strategy

This project uses **S3-compatible object storage via Active Storage** for image
and media storage in production. The reference deployment uses Scaleway Object
Storage, while the adapter accepts other S3-compatible providers.

## Decision

- Storage backend: S3-compatible API via Active Storage
- URL mode: `rails_storage_redirect`
- Variant processor: `mini_magick`
- CDN direction: provider-neutral; add one only after measuring the installation

This keeps the storage layer Rails-native and portable between compatible
European providers without changing application code.

## Why This Shape

### Chosen path

S3 + Active Storage + proxy URLs is the simplest durable baseline:

- it uses Rails primitives instead of adding a dedicated image service now
- it keeps image attachments and variants in one place
- it allows an optional CDN to cache image responses at the edge once an
  installation's measured needs justify the extra infrastructure

### Options considered

- **S3-compatible storage + Active Storage variants**
  - Pros: Rails-native, portable, no extra image service
  - Cons: first-request variant generation happens in the app process
- **S3-compatible storage + imgproxy**
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
- Keep originals in object storage; generate variants lazily on first request

## Production Configuration

Set these environment variables:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `AWS_S3_BUCKET`
- `AWS_ENDPOINT_URL_S3`
- `AWS_PUBLIC_BUCKET` (`false` for the generic signed-URL reference)

`config/storage.yml` points production at the adapter named `amazon`; despite
that Rails adapter name, it accepts any compatible endpoint. Development and
test continue using local/test disk storage. See [Deployment](deployment.md)
for the Scaleway endpoint and CORS setup.

## Local And CI Requirements

The current processor choice is `mini_magick`, so environments that run variant generation need ImageMagick available.

- macOS: `brew install imagemagick`
- Ubuntu CI: install `imagemagick` before running the test suite
