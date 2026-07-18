# A single media asset (macro image, microscopy image, or video) attached to
# a {Material}.
#
# Assets are modelled as their own table rather than Active Storage attachments
# directly on {Material} so that:
#
#   * Microscopy images have a stable order (`position` = `m1` → 0, `m2` → 1,
#     ...) that survives attachment reshuffling.
#   * The DB can enforce "at most one video per material" via a partial unique
#     index on `(material_id, kind)` while allowing ordered macro photos and
#     microscopies.
#   * Future per-asset metadata (captions, credits) has a home without
#     reshaping.
#
# Each row has exactly one Active Storage file attachment. The importer
# (`lib/material_assets_importer.rb`) is responsible for walking a local
# folder that mirrors the SMEs' Drive layout and creating rows with files
# attached; see `.munkit/specs/2026-04-17-materials-database/notes.md`.
class MaterialAsset < LibraryItemAsset
  alias_attribute :material_id, :library_item_id

  belongs_to :material, foreign_key: :library_item_id, inverse_of: :assets
end
