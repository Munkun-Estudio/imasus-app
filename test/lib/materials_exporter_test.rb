require "test_helper"
require Rails.root.join("lib", "materials_exporter")

class MaterialsExporterTest < ActiveSupport::TestCase
  test "exports material text, metadata, and tags" do
    Tag.where(facet: "origin_type", slug: "plants").destroy_all
    Material.where(slug: "exported-material").destroy_all

    tag = Tag.create!(
      facet: "origin_type",
      slug: "plants",
      name_translations: { "en" => "Plants" }
    )
    material = Material.create!(
      trade_name: "Exported material",
      supplier_name: "Supplier",
      supplier_url: "https://example.com",
      material_of_origin: "Orange",
      availability_status: "commercial",
      position: 12,
      description_translations: { "en" => "Edited production description" },
      sensorial_qualities_translations: { "en" => "Soft" }
    )
    material.taggings.create!(tag: tag)

    payload = MaterialsExporter.new(Material.where(id: material.id)).export
    exported = payload.fetch(:materials).first

    assert_equal 1, payload.fetch(:count)
    assert_equal material.slug, exported.fetch(:slug)
    assert_equal "Edited production description", exported.fetch(:description_translations).fetch("en")
    assert_equal "Supplier", exported.fetch(:supplier_name)
    assert_equal({ "origin_type" => [ "plants" ] }, exported.fetch(:tags))
  end
end
