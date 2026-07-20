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

  validates :kind, presence: true
  before_validation :sync_legacy_role

  private

  # Historical material videos include records imported before MIME-type
  # enforcement. Keep their established validation contract; generic
  # manifest-managed assets are validated by LibraryItemAsset.
  def file_matches_role
    super if managed_by_manifest?
  end

  def role_cardinality
    super
    errors.add(:kind, :taken) if errors.added?(:role, :taken)
  end

  def sync_legacy_role
    if role.present? && kind.blank? && KINDS.include?(role)
      self.kind = role
    elsif kind.present?
      self.role = kind
    end
  end
end
