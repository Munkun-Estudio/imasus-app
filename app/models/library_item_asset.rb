# Ordered media attached to a generic Library item.
class LibraryItemAsset < ApplicationRecord
  KINDS = %w[macro microscopy video].freeze
  SINGLETON_KINDS = %w[video].freeze

  enum :kind, KINDS.each_with_index.to_h

  belongs_to :library_item, inverse_of: :assets

  has_one_attached :file
  has_one_attached :poster

  validates :kind, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: %i[library_item_id kind] }
  validate :file_must_be_attached
  validate :singleton_kind_not_duplicated

  private

  def file_must_be_attached
    errors.add(:file, :blank) unless file.attached?
  end

  def singleton_kind_not_duplicated
    return unless SINGLETON_KINDS.include?(kind)
    return unless library_item_id

    scope = self.class.where(library_item_id:, kind: self.class.kinds[kind])
    scope = scope.where.not(id:) if persisted?
    errors.add(:kind, :taken) if scope.exists?
  end
end
