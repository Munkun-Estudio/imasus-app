require "json"

# Serializes production material catalogue content before media refresh work.
#
# This exporter is deliberately read-only. It captures the text fields that
# curators may have edited directly in production, plus enough metadata and tag
# links to recreate or compare a material row without relying on stale seeds.
class MaterialsExporter
  def initialize(scope = Material.all)
    @scope = scope
  end

  def export
    {
      exported_at: Time.current.iso8601,
      count:       materials.size,
      materials:   materials.map { |material| material_payload(material) }
    }
  end

  private

  def materials
    @materials ||= @scope
                   .includes(:tags)
                   .order(:position, :slug)
                   .to_a
  end

  def material_payload(material)
    {
      id:                                   material.id,
      slug:                                 material.slug,
      trade_name:                           material.trade_name,
      supplier_name:                        material.supplier_name,
      supplier_url:                         material.supplier_url,
      material_of_origin:                   material.material_of_origin,
      availability_status:                  material.availability_status,
      position:                             material.position,
      description_translations:             material.description_translations,
      sensorial_qualities_translations:     material.sensorial_qualities_translations,
      what_problem_it_solves_translations:  material.what_problem_it_solves_translations,
      interesting_properties_translations:  material.interesting_properties_translations,
      structure_translations:               material.structure_translations,
      tags:                                 tag_payload(material)
    }
  end

  def tag_payload(material)
    material.tags
            .sort_by { |tag| [ tag.facet, tag.slug ] }
            .group_by(&:facet)
            .transform_values { |tags| tags.map(&:slug) }
  end
end
