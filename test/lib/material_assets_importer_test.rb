require "test_helper"
require Rails.root.join("lib", "material_assets_importer")

class MaterialAssetsImporterTest < ActiveSupport::TestCase
  SAMPLE_IMAGE = Rails.root.join("test", "fixtures", "files", "sample-image.png")

  setup do
    @tmp_root = Pathname(Dir.mktmpdir("material-assets-"))
    @material = Material.create!(
      trade_name:               "Lifematerials Kapok",
      availability_status:      "commercial",
      description_translations: { "en" => "Kapok sample" }
    )
  end

  teardown do
    FileUtils.rm_rf(@tmp_root) if @tmp_root&.exist?
  end

  def build_drive_folder(folder_name, files:)
    folder = @tmp_root.join(folder_name)
    folder.mkpath
    files.each do |filename, source|
      if source == :image
        FileUtils.cp(SAMPLE_IMAGE, folder.join(filename))
      else
        File.write(folder.join(filename), source)
      end
    end
    folder
  end

  test "attaches the macro, ordered microscopies, and the video for a folder" do
    build_drive_folder(
      "Lifematerials-Kapok",
      files: {
        "Lifematerials-Kapok.jpg"    => :image,
        "Lifematerials-Kapok-m1.jpg" => :image,
        "Lifematerials-Kapok-m2.jpg" => :image,
        "Lifematerials-Kapok-m3.jpg" => :image,
        "Lifematerials-Kapok.mp4"    => "fake-mp4-bytes"
      }
    )

    MaterialAssetsImporter.new(@tmp_root).import!

    @material.reload

    assert @material.macro_asset.present?
    assert @material.macro_asset.file.attached?

    positions = @material.microscopies.pluck(:position)
    assert_equal [ 0, 1, 2 ], positions

    assert @material.video_asset.present?
    assert @material.video_asset.file.attached?
  end

  test "is idempotent when run twice" do
    build_drive_folder(
      "Lifematerials-Kapok",
      files: {
        "Lifematerials-Kapok.jpg"    => :image,
        "Lifematerials-Kapok-m1.jpg" => :image
      }
    )

    MaterialAssetsImporter.new(@tmp_root).import!
    initial_count = MaterialAsset.count

    MaterialAssetsImporter.new(@tmp_root).import!

    assert_equal initial_count, MaterialAsset.count
  end

  test "reports folders whose slug does not match any Material" do
    build_drive_folder(
      "Mystery-Material",
      files: { "Mystery-Material.jpg" => :image }
    )

    result = MaterialAssetsImporter.new(@tmp_root).import!

    assert_includes result.skipped_missing_materials, "mystery-material"
    assert_equal 0, MaterialAsset.count
  end

  test "ignores files that do not match the naming convention" do
    build_drive_folder(
      "Lifematerials-Kapok",
      files: {
        "Lifematerials-Kapok.jpg"  => :image,
        "random-notes.txt"          => "notes",
        "Lifematerials-Kapok.heic" => "unknown"
      }
    )

    result = MaterialAssetsImporter.new(@tmp_root).import!

    assert_equal 1, MaterialAsset.count
    assert_equal 2, result.files_ignored.size
  end

  test "folder name is matched case-insensitively against the material slug" do
    build_drive_folder(
      "LIFEMATERIALS-Kapok",
      files: { "LIFEMATERIALS-Kapok.jpg" => :image }
    )

    MaterialAssetsImporter.new(@tmp_root).import!

    assert_not_nil @material.reload.macro_asset
  end
end
