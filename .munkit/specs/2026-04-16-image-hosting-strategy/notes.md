# Image Hosting Strategy — Notes

Implementation notes, discoveries, and scratch space. Update as work progresses.

## Existing AWS relationship

The IMASUS project already uses AWS for the newsletter. This means an AWS account, billing, and likely an IAM user already exist. The S3 bucket for this app will be new but within the same account.

## Rails 8 defaults

Rails 8 includes `image_processing` in the default Gemfile. Check whether `ruby-vips` (preferred) or `mini_magick` is configured. Vips is faster and lower-memory for batch variant generation, which matters for the micrograph set.

Current implementation choice:

- Processor: `mini_magick`
- Reason: lower contributor friction in the current environment; ImageMagick is available locally while `vips` is not.
- Revisit trigger: if material-image throughput becomes a bottleneck, switching the processor to `:vips` remains possible without changing the storage layer.

## Micrograph dataset

The materials micrographs are described as a "huge amount" — exact count unknown. SEM images tend to be high-resolution (2048×1536 or larger). Variant generation strategy needs to handle:

- Thumbnail (~200px) for catalogue grid
- Card (~400px) for material cards and embeds
- Detail (~1200px) for material detail page with zoom
- Original preserved for download / full-resolution viewing

## Open Questions

- Exact micrograph count and total file size — affects S3 cost estimate and seed strategy.
- Do we need a bulk import tool for images, or will they be attached via the seed rake task one by one?
- Video strategy is explicitly deferred — but students will upload videos to log entries. S3 direct upload for large files? Or defer video to a later spec?

## Implementation findings

- Active Storage was not installed yet on this branch; the spec adds the standard Active Storage tables.
- Production now targets the `amazon` storage service in `config/storage.yml`, using environment variables rather than checked-in credentials.
- Active Storage URLs are configured for `rails_storage_proxy` so a CDN can be added in front of the app without changing future feature code.
- Shared variant presets live in `ImageVariants`; views should render them through `image_variant_tag(...)` so lazy loading and explicit dimensions are the default.
