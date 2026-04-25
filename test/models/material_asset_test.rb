require "test_helper"

class MaterialAssetTest < ActiveSupport::TestCase
  SAMPLE_IMAGE = Rails.root.join("test", "fixtures", "files", "sample-image.png")

  def material
    @material ||= Material.create!(
      trade_name:               "Sample material",
      availability_status:      "commercial",
      description_translations: { "en" => "Sample description" }
    )
  end

  def build_asset(overrides = {})
    asset = MaterialAsset.new({
      material: material,
      kind:     "macro",
      position: 0
    }.merge(overrides))
    asset.file.attach(io: File.open(SAMPLE_IMAGE), filename: "sample.png", content_type: "image/png")
    asset
  end

  # --- Validations -----------------------------------------------------------

  test "valid with material, kind, position, and an attached file" do
    assert build_asset.valid?
  end

  test "requires a material" do
    asset = build_asset(material: nil)
    assert_not asset.valid?
    assert asset.errors[:material].any?
  end

  test "requires a kind" do
    asset = MaterialAsset.new(material: material, position: 0)
    asset.file.attach(io: File.open(SAMPLE_IMAGE), filename: "sample.png", content_type: "image/png")

    assert_not asset.valid?
    assert asset.errors[:kind].any?
  end

  test "rejects an unknown kind" do
    assert_raises ArgumentError do
      MaterialAsset.new(kind: "banner")
    end
  end

  test "accepts each of the three canonical kinds" do
    %w[macro microscopy video].each_with_index do |kind, position|
      asset = build_asset(kind: kind, position: position)
      assert asset.valid?, "expected '#{kind}' to validate: #{asset.errors.full_messages.to_sentence}"
    end
  end

  test "requires an attached file" do
    asset = MaterialAsset.new(material: material, kind: "macro", position: 0)

    assert_not asset.valid?
    assert asset.errors[:file].any?
  end

  # --- Uniqueness ------------------------------------------------------------

  test "allows only one macro per material" do
    build_asset(kind: "macro").save!
    dup = build_asset(kind: "macro")
    assert_not dup.valid?
    assert dup.errors[:kind].any?
  end

  test "allows only one video per material" do
    build_asset(kind: "video").save!
    dup = build_asset(kind: "video")
    assert_not dup.valid?
    assert dup.errors[:kind].any?
  end

  test "allows multiple microscopies as long as positions differ" do
    build_asset(kind: "microscopy", position: 0).save!
    second = build_asset(kind: "microscopy", position: 1)
    assert second.valid?, second.errors.full_messages.to_sentence
  end

  test "rejects two microscopies at the same position for the same material" do
    build_asset(kind: "microscopy", position: 0).save!
    dup = build_asset(kind: "microscopy", position: 0)
    assert_not dup.valid?
    assert dup.errors[:position].any?
  end

  # --- Material accessors ----------------------------------------------------

  test "material.macro_asset returns the macro asset" do
    macro = build_asset(kind: "macro")
    macro.save!

    assert_equal macro, material.reload.macro_asset
  end

  test "material.macro_asset uses preloaded assets when available" do
    macro = build_asset(kind: "macro")
    macro.save!

    preloaded_material = Material.includes(:assets).find(material.id)

    assert_no_queries do
      assert_equal macro, preloaded_material.macro_asset
    end
  end

  test "material.macro_asset returns nil when none exists" do
    assert_nil material.macro_asset
  end

  test "material.microscopies returns microscopies ordered by position" do
    m2 = build_asset(kind: "microscopy", position: 1); m2.save!
    m1 = build_asset(kind: "microscopy", position: 0); m1.save!
    m3 = build_asset(kind: "microscopy", position: 2); m3.save!

    assert_equal [ m1, m2, m3 ], material.reload.microscopies.to_a
  end

  test "material.microscopies uses preloaded assets when available" do
    m2 = build_asset(kind: "microscopy", position: 1); m2.save!
    m1 = build_asset(kind: "microscopy", position: 0); m1.save!
    m3 = build_asset(kind: "microscopy", position: 2); m3.save!

    preloaded_material = Material.includes(:assets).find(material.id)

    assert_no_queries do
      assert_equal [ m1, m2, m3 ], preloaded_material.microscopies
    end
  end

  test "material.video_asset returns the video asset" do
    video = build_asset(kind: "video")
    video.save!

    assert_equal video, material.reload.video_asset
  end

  test "material.video_asset uses preloaded assets when available" do
    video = build_asset(kind: "video")
    video.save!

    preloaded_material = Material.includes(:assets).find(material.id)

    assert_no_queries do
      assert_equal video, preloaded_material.video_asset
    end
  end

  test "material.video_asset returns nil when none exists" do
    assert_nil material.video_asset
  end
end
