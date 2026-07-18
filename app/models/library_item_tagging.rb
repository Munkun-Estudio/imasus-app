# Normalized many-to-many relationship between Library items and taxonomy terms.
class LibraryItemTagging < ApplicationRecord
  belongs_to :library_item, inverse_of: :taggings
  belongs_to :library_taxonomy_term, inverse_of: :taggings

  validates :library_item_id, uniqueness: { scope: :library_taxonomy_term_id }
end
