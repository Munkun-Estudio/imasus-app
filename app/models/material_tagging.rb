# Join record linking a {Material} to a {Tag}.
#
# Each tag belongs to exactly one facet (`origin_type`, `textile_imitating`,
# `application`), so a material can carry several taggings across different
# facets — one tagging per selected tag. The `(material_id, tag_id)`
# uniqueness guards against accidentally duplicating the same tag on a
# material when re-running seed loaders.
class MaterialTagging < LibraryItemTagging
  alias_attribute :material_id, :library_item_id
  alias_attribute :tag_id, :library_taxonomy_term_id

  belongs_to :material, foreign_key: :library_item_id, inverse_of: :taggings
  belongs_to :tag, foreign_key: :library_taxonomy_term_id, inverse_of: :taggings

  validates :material_id, uniqueness: { scope: :tag_id }
end
