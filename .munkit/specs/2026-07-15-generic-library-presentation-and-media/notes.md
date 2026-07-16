# Notes: 2026-07-15-generic-library-presentation-and-media

## Initial discovery

- `MaterialsHelper` and material views encode the five narrative attributes,
  English fallback, tag facets, supplier metadata, and gallery layout.
- `MaterialAsset` and the importer/preprocessor/auditor tasks encode macro,
  microscopy, and video naming conventions tied to the partner source folders.
- Active Storage attachment continuity is part of the migration contract; moving
  blobs is unnecessary if record/attachment relationships can be remapped safely.
- Existing import tools contain useful classification and dry-run ideas but should
  become a profile-specific adapter over the generic import contract.

## Open questions

- Define the finite v1 renderer field kinds only after mapping every current
  Materials field and the example non-IMASUS ficha.
- Decide which specialised microscopy/video behaviours remain optional item-type
  presentation hints rather than generic core concepts.
