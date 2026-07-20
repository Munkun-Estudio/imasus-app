# Ordered media attached to a generic Library item.
class LibraryItemAsset < ApplicationRecord
  include Translatable

  attr_accessor :validation_manifest

  KINDS = %w[macro microscopy video].freeze

  enum :kind, KINDS.each_with_index.to_h

  translates :alt_text, :caption

  belongs_to :library_item, inverse_of: :assets

  has_one_attached :file
  has_one_attached :poster

  scope :active, -> { where(retired_at: nil) }

  validates :role, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: %i[library_item_id role] }
  validate :file_must_be_attached
  validate :role_is_declared
  validate :role_cardinality
  validate :file_matches_role

  def alt_text(locale: I18n.locale)
    alt_text_in(locale).presence ||
      alt_text_in(self.class.base_locale).presence ||
      library_item.title_in(locale).presence ||
      library_item.title
  end

  private

  def file_must_be_attached
    errors.add(:file, :blank) unless file.attached?
  end

  def role_definition
    type = if validation_manifest && library_item
      validation_manifest.item_type(library_item.item_type)
    else
      library_item&.item_type_definition
    end
    type&.media_role(role)
  end

  def role_is_declared
    errors.add(:role, :inclusion) if role.present? && role_definition.nil?
  end

  def role_cardinality
    return if role_definition&.multiple || library_item_id.nil?

    scope = self.class.active.where(library_item_id:, role:)
    scope = scope.where.not(id:) if persisted?
    errors.add(:role, :taken) if scope.exists?
  end

  def file_matches_role
    return unless file.attached? && role_definition

    unless role_definition.allowed_types.include?(file.blob.content_type)
      errors.add(:file, "must be one of: #{role_definition.allowed_types.join(', ')}")
    end
    if file.blob.byte_size > role_definition.max_bytes
      errors.add(:file, "is too large (maximum #{role_definition.max_bytes} bytes)")
    end
  end
end
