require "test_helper"
require "open3"
require Rails.root.join("lib", "material_assets_preprocessor")

class MaterialAssetsPreprocessorTest < ActiveSupport::TestCase
  setup do
    skip "ImageMagick is required for MaterialAssetsPreprocessor tests" unless MaterialAssetsPreprocessor.magick_available?

    @tmp_input = Pathname(Dir.mktmpdir("material-assets-source-"))
    @tmp_output = Pathname(Dir.mktmpdir("material-assets-output-"))
  end

  teardown do
    FileUtils.rm_rf(@tmp_input) if @tmp_input&.exist?
    FileUtils.rm_rf(@tmp_output) if @tmp_output&.exist?
  end

  def create_image(path, size:)
    success = system("magick", "-size", size, "xc:orange", path.to_s, out: File::NULL, err: File::NULL)
    raise "failed to create sample image at #{path}" unless success
  end

  def dimensions_for(path)
    stdout, status = Open3.capture2("magick", "identify", "-format", "%wx%h", path.to_s)
    assert status.success?, "identify failed for #{path}"

    stdout.strip.split("x").map(&:to_i)
  end

  test "prepares a single material folder into importer-ready jpgs" do
    folder = @tmp_input.join("Lifematerials-Kapok")
    folder.mkpath

    create_image(folder.join("Lifematerials-Kapok.png"), size: "5000x3000")
    create_image(folder.join("Lifematerials-Kapok-m1.tif"), size: "4200x2800")
    File.write(folder.join("Lifematerials-Kapok.mp4"), "fake-mp4")
    File.write(folder.join("notes.txt"), "ignored")

    result = MaterialAssetsPreprocessor.new(folder, output_path: @tmp_output).prepare!

    output_folder = @tmp_output.join("Lifematerials-Kapok")
    macro = output_folder.join("Lifematerials-Kapok.jpg")
    microscopy = output_folder.join("Lifematerials-Kapok-m1.jpg")
    video = output_folder.join("Lifematerials-Kapok.mp4")

    assert_equal 1, result.folders_processed
    assert_equal 2, result.images_written
    assert_equal 1, result.videos_copied
    assert_equal [ "notes.txt" ], result.files_ignored

    assert macro.exist?
    assert microscopy.exist?
    assert video.exist?

    assert_equal "fake-mp4", File.read(video)
    assert_equal [ 3600, 2160 ], dimensions_for(macro)
    assert_equal [ 2400, 1600 ], dimensions_for(microscopy)
  end

  test "processes every material subfolder when given a synced root" do
    kapok = @tmp_input.join("Lifematerials-Kapok")
    musa = @tmp_input.join("Pyratex-Musa-1")
    kapok.mkpath
    musa.mkpath

    create_image(kapok.join("Lifematerials-Kapok.jpg"), size: "1200x800")
    create_image(musa.join("Pyratex-Musa-1.jpg"), size: "1200x800")

    result = MaterialAssetsPreprocessor.new(@tmp_input, output_path: @tmp_output).prepare!

    assert_equal 2, result.folders_processed
    assert @tmp_output.join("Lifematerials-Kapok", "Lifematerials-Kapok.jpg").exist?
    assert @tmp_output.join("Pyratex-Musa-1", "Pyratex-Musa-1.jpg").exist?
  end

  test "honours custom size limits" do
    folder = @tmp_input.join("Lifematerials-Kapok")
    folder.mkpath

    create_image(folder.join("Lifematerials-Kapok.png"), size: "5000x3000")
    create_image(folder.join("Lifematerials-Kapok-m1.tif"), size: "4200x2800")

    MaterialAssetsPreprocessor.new(
      folder,
      output_path: @tmp_output,
      macro_long_edge: 1800,
      microscopy_long_edge: 900
    ).prepare!

    output_folder = @tmp_output.join("Lifematerials-Kapok")

    assert_equal [ 1800, 1080 ], dimensions_for(output_folder.join("Lifematerials-Kapok.jpg"))
    assert_equal [ 900, 600 ], dimensions_for(output_folder.join("Lifematerials-Kapok-m1.jpg"))
  end
end
