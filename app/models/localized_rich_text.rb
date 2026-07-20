class LocalizedRichText < ApplicationRecord
  belongs_to :record, polymorphic: true
  has_rich_text :content

  validates :name,
            presence: true,
            format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :locale,
            presence: true,
            inclusion: { in: ->(_record) { Rails.configuration.site.locales.available } }
  validates :locale, uniqueness: { scope: %i[record_type record_id name] }

  def content_present?
    content.body&.to_s.to_s.strip.present?
  end
end
