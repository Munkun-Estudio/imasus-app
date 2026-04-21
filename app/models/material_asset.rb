# A single media asset (macro image, microscopy image, or video) attached to
# a {Material}.
#
# Assets are modelled as their own table rather than Active Storage attachments
# directly on {Material} so that:
#
#   * Microscopy images have a stable order (`position` = `m1` → 0, `m2` → 1,
#     ...) that survives attachment reshuffling.
#   * The DB can enforce "at most one macro and one video per material" via a
#     partial unique index on `(material_id, kind)` where `kind` is a
#     singleton kind (macro or video).
#   * Future per-asset metadata (captions, credits) has a home without
#     reshaping.
#
# Each row has exactly one Active Storage file attachment. The importer
# (`lib/material_assets_importer.rb`) is responsible for walking a local
# folder that mirrors the SMEs' Drive layout and creating rows with files
# attached; see `.munkit/specs/2026-04-17-materials-database/notes.md`.
class MaterialAsset < ApplicationRecord
  KINDS = %w[macro microscopy video].freeze

  SINGLETON_KINDS = %w[macro video].freeze

  enum :kind, KINDS.each_with_index.to_h

  belongs_to :material

  has_one_attached :file

  validates :kind,     presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: [ :material_id, :kind ] }

  validate :file_must_be_attached
  validate :singleton_kind_not_duplicated

  private

  def file_must_be_attached
    errors.add(:file, :blank) unless file.attached?
  end

  def singleton_kind_not_duplicated
    return unless SINGLETON_KINDS.include?(kind)
    return unless material_id

    scope = self.class.where(material_id: material_id, kind: self.class.kinds[kind])
    scope = scope.where.not(id: id) if persisted?

    errors.add(:kind, :taken) if scope.exists?
  end
end
