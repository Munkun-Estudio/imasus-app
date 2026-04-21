# Join record linking a {Material} to a {Tag}.
#
# Each tag belongs to exactly one facet (`origin_type`, `textile_imitating`,
# `application`), so a material can carry several taggings across different
# facets — one tagging per selected tag. The `(material_id, tag_id)`
# uniqueness guards against accidentally duplicating the same tag on a
# material when re-running seed loaders.
class MaterialTagging < ApplicationRecord
  belongs_to :material
  belongs_to :tag

  validates :material_id, uniqueness: { scope: :tag_id }
end
