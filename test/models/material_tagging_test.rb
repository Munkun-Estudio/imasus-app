require "test_helper"

class MaterialTaggingTest < ActiveSupport::TestCase
  def material
    @material ||= Material.create!(
      trade_name:               "Sample material",
      availability_status:      "commercial",
      description_translations: { "en" => "Sample description" }
    )
  end

  def tag
    @tag ||= Tag.create!(
      facet:             "origin_type",
      slug:              "plants",
      name_translations: { "en" => "Plants" }
    )
  end

  test "valid with material and tag" do
    assert MaterialTagging.new(material: material, tag: tag).valid?
  end

  test "requires a material" do
    record = MaterialTagging.new(tag: tag)
    assert_not record.valid?
    assert record.errors[:material].any?
  end

  test "requires a tag" do
    record = MaterialTagging.new(material: material)
    assert_not record.valid?
    assert record.errors[:tag].any?
  end

  test "enforces uniqueness on (material, tag)" do
    MaterialTagging.create!(material: material, tag: tag)
    dup = MaterialTagging.new(material: material, tag: tag)
    assert_not dup.valid?
  end
end
