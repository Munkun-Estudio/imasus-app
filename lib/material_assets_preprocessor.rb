require "fileutils"
require "open3"
require "pathname"
require_relative "material_assets_naming"

# Normalises a local material-media folder tree into a browser-friendly,
# importer-ready mirror:
#
#   * macro images -> JPG, long edge capped at 3600px by default
#   * microscopy images -> JPG, long edge capped at 2400px by default
#   * videos -> copied through unchanged
#
# The output tree preserves the SMEs' folder and basename convention so
# {MaterialAssetsImporter} can ingest it directly afterwards.
class MaterialAssetsPreprocessor
  SOURCE_IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .tif .tiff .webp].freeze

  DEFAULT_MACRO_LONG_EDGE = 3600
  DEFAULT_MICROSCOPY_LONG_EDGE = 2400
  DEFAULT_JPEG_QUALITY = 90

  Result = Struct.new(
    :folders_processed, :images_written, :videos_copied, :files_ignored,
    keyword_init: true
  ) do
    def summary
      "#{folders_processed} folder(s) processed, #{images_written} image(s) written, " \
        "#{videos_copied} video(s) copied, #{files_ignored.size} file(s) ignored"
    end
  end

  def self.magick_available?
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
      File.executable?(File.join(dir, "magick"))
    end
  end

  def initialize(source_path, output_path:, macro_long_edge: DEFAULT_MACRO_LONG_EDGE,
                 microscopy_long_edge: DEFAULT_MICROSCOPY_LONG_EDGE,
                 quality: DEFAULT_JPEG_QUALITY)
    @source = Pathname(source_path)
    @output = Pathname(output_path)
    @macro_long_edge = Integer(macro_long_edge)
    @microscopy_long_edge = Integer(microscopy_long_edge)
    @quality = Integer(quality)
  end

  def prepare!
    validate!
    @output.mkpath

    result = Result.new(
      folders_processed: 0,
      images_written: 0,
      videos_copied: 0,
      files_ignored: []
    )

    source_folders.each do |folder|
      prepare_folder(folder, result)
    end

    result
  end

  private

  def validate!
    raise ArgumentError, "Source path does not exist: #{@source}" unless @source.exist?
    raise ArgumentError, "Source path must be a directory: #{@source}" unless @source.directory?
    raise ArgumentError, "Output path must differ from source path" if @source.expand_path == @output.expand_path
    raise ArgumentError, "ImageMagick 'magick' command is not available on PATH" unless self.class.magick_available?
    raise ArgumentError, "Macro long edge must be positive" unless @macro_long_edge.positive?
    raise ArgumentError, "Microscopy long edge must be positive" unless @microscopy_long_edge.positive?
    raise ArgumentError, "JPEG quality must be between 1 and 100" unless (1..100).cover?(@quality)
  end

  def source_folders
    children = @source.children.sort

    if children.any? { |child| child.file? && recognised?(child) }
      [ @source ]
    else
      children.select(&:directory?)
    end
  end

  def recognised?(file)
    kind, = MaterialAssetsNaming.classify(file, image_extensions: SOURCE_IMAGE_EXTENSIONS)
    !kind.nil?
  end

  def prepare_folder(folder, result)
    destination_folder = @output.join(folder.basename)
    destination_folder.mkpath
    result.folders_processed += 1

    folder.children.select(&:file?).sort.each do |file|
      kind, = MaterialAssetsNaming.classify(file, image_extensions: SOURCE_IMAGE_EXTENSIONS)

      case kind
      when :macro
        prepare_image(file, destination_folder.join(jpg_filename_for(file)), @macro_long_edge)
        result.images_written += 1
      when :microscopy
        prepare_image(file, destination_folder.join(jpg_filename_for(file)), @microscopy_long_edge)
        result.images_written += 1
      when :video
        FileUtils.cp(file, destination_folder.join(file.basename), preserve: true)
        result.videos_copied += 1
      else
        result.files_ignored << relative_path_for(file)
      end
    end
  end

  def prepare_image(source, destination, long_edge)
    stdout, stderr, status = Open3.capture3(
      "magick", source.to_s,
      "-auto-orient",
      "-resize", "#{long_edge}x#{long_edge}>",
      "-strip",
      "-background", "white",
      "-alpha", "remove",
      "-alpha", "off",
      "-colorspace", "sRGB",
      "-sampling-factor", "4:2:0",
      "-interlace", "Plane",
      "-quality", @quality.to_s,
      destination.to_s
    )

    return if status.success?

    message = stderr.strip
    message = stdout.strip if message.empty?
    raise RuntimeError, "ImageMagick failed for #{source}: #{message}"
  end

  def jpg_filename_for(file)
    "#{file.basename(file.extname)}.jpg"
  end

  def relative_path_for(file)
    file.relative_path_from(@source).to_s
  rescue ArgumentError
    file.basename.to_s
  end
end
