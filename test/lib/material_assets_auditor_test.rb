require "test_helper"
require Rails.root.join("lib", "material_assets_auditor")

class MaterialAssetsAuditorTest < ActiveSupport::TestCase
  SAMPLE_IMAGE = Rails.root.join("test", "fixtures", "files", "sample-image.png")

  setup do
    @tmp_root = Pathname(Dir.mktmpdir("material-assets-audit-"))
  end

  teardown do
    FileUtils.rm_rf(@tmp_root) if @tmp_root&.exist?
  end

  test "reports materials without an import-media folder" do
    with_media = create_material("Material With Media")
    without_media = create_material("Material Without Media")
    build_folder(with_media.slug, files: { "#{with_media.slug}.jpg" => :image })

    result = MaterialAssetsAuditor.new(@tmp_root).audit

    assert_includes result.materials_without_import_media, [ without_media.slug, without_media.trade_name ]
    assert_not_includes result.materials_without_import_media, [ with_media.slug, with_media.trade_name ]
  end

  test "applies known source slug aliases" do
    material = create_material("Pyratex Freshness 1", slug: "pyratex-freshness-1")
    build_folder("PYRATEX-freshness-4", files: { "PYRATEX-freshness-4.jpg" => :image })

    result = MaterialAssetsAuditor.new(@tmp_root).audit

    assert_not_includes result.materials_without_import_media, [ material.slug, material.trade_name ]
  end

  test "does not alias confirmed numbered material variants" do
    first = create_material("ECOALF Recycled cotton 1", slug: "ecoalf-recycled-cotton-1")
    second = create_material("ECOALF Recycled cotton 2", slug: "ecoalf-recycled-cotton-2")
    build_folder("ECOALF-Recycled-cotton-1", files: { "ECOALF-recycled-cotton-1.png" => :image })
    build_folder("ECOALF-Recycled-cotton-2", files: { "ECOALF-recycled-cotton-2.png" => :image })

    result = MaterialAssetsAuditor.new(@tmp_root).audit

    assert_not_includes result.materials_without_import_media, [ first.slug, first.trade_name ]
    assert_not_includes result.materials_without_import_media, [ second.slug, second.trade_name ]
  end

  test "reports unmatched folders and folders with multiple macros" do
    build_folder(
      "Mystery-Material",
      files: {
        "Mystery-Material.jpg"   => :image,
        "Mystery-Material_2.jpg" => :image
      }
    )

    result = MaterialAssetsAuditor.new(@tmp_root).audit

    assert_equal [ "mystery-material" ], result.folders_without_material.map { |row| row[:slug] }
    assert_equal [ "mystery-material" ], result.folders_with_multiple_macros.map { |row| row[:slug] }
  end

  test "reports folders with multiple videos" do
    material = create_material("Material With Videos")
    build_folder(
      material.slug,
      files: {
        "#{material.slug}.jpg" => :image,
        "first.mp4"            => "video-1",
        "second.mp4"           => "video-2"
      }
    )

    result = MaterialAssetsAuditor.new(@tmp_root).audit
    row = result.folders_with_multiple_videos.find { |entry| entry[:slug] == material.slug }

    assert row
    assert_equal 2, row[:video_count]
    assert_equal [ "first.mp4", "second.mp4" ], row[:videos]
  end

  private

  def create_material(trade_name, slug: nil)
    Material.where(slug: slug || trade_name.parameterize).destroy_all
    Material.create!(
      trade_name:               trade_name,
      slug:                     slug,
      availability_status:      "commercial",
      description_translations: { "en" => "Description for #{trade_name}" }
    )
  end

  def build_folder(folder_name, files:)
    folder = @tmp_root.join(folder_name)
    folder.mkpath

    files.each do |filename, source|
      if source == :image
        FileUtils.cp(SAMPLE_IMAGE, folder.join(filename))
      else
        File.write(folder.join(filename), source)
      end
    end
  end
end
