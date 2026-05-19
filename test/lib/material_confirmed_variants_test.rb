require "test_helper"
require Rails.root.join("lib", "material_confirmed_variants")

class MaterialConfirmedVariantsTest < ActiveSupport::TestCase
  setup do
    cleanup_confirmed_variant_materials
  end

  teardown do
    cleanup_confirmed_variant_materials
  end

  def cleanup_confirmed_variant_materials
    Material.where(slug: [
      "ecoalf-recycled-cotton-1-2",
      "ecoalf-recycled-cotton-1",
      "ecoalf-recycled-cotton-2",
      "ecoalf-recycled-polyester-1-2",
      "ecoalf-recycled-polyester-1",
      "ecoalf-recycled-polyester-2",
      "pyratex-upcycled-2",
      "pyratex-upcycled-5"
    ]).destroy_all
  end

  test "dry run reports changes without mutating rows" do
    source = create_material("ecoalf-recycled-cotton-1-2", "ECOALF-Recycled cotton 1(2)")

    result = MaterialConfirmedVariants.new.call

    assert result.changes.any? { |change| change.include?("ecoalf-recycled-cotton-1-2 -> ecoalf-recycled-cotton-1") }
    assert_equal "ecoalf-recycled-cotton-1-2", source.reload.slug
    assert_nil Material.find_by(slug: "ecoalf-recycled-cotton-2")
  end

  test "apply renames placeholder source and clones variant with production text and tags" do
    Tag.where(facet: "origin_type", slug: "recycled_materials").destroy_all
    tag = Tag.create!(
      facet: "origin_type",
      slug: "recycled_materials",
      name_translations: { "en" => "Recycled materials" }
    )
    source = create_material(
      "ecoalf-recycled-cotton-1-2",
      "ECOALF-Recycled cotton 1(2)",
      description_translations: { "en" => "Production-edited text" }
    )
    source.taggings.create!(tag: tag)

    MaterialConfirmedVariants.new(apply: true).call

    canonical = Material.find_by!(slug: "ecoalf-recycled-cotton-1")
    variant = Material.find_by!(slug: "ecoalf-recycled-cotton-2")

    assert_equal "ECOALF-Recycled cotton 1", canonical.trade_name
    assert_equal "ECOALF-Recycled cotton 2", variant.trade_name
    assert_equal "Production-edited text", variant.description_translations.fetch("en")
    assert_equal [ tag.id ], variant.tag_ids
  end

  test "apply clones pyratex upcycled 5 from upcycled 2" do
    create_material("pyratex-upcycled-2", "Pyratex upcycled 2")

    MaterialConfirmedVariants.new(apply: true).call

    assert_not_nil Material.find_by(slug: "pyratex-upcycled-5")
  end

  private

  def create_material(slug, trade_name, overrides = {})
    Material.create!({
      slug: slug,
      trade_name: trade_name,
      availability_status: "commercial",
      description_translations: { "en" => "Description for #{trade_name}" }
    }.merge(overrides))
  end
end
