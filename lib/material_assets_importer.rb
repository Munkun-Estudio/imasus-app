# Walks a local directory that mirrors the SMEs' Drive folder layout and
# upserts the corresponding {MaterialAsset} rows with Active Storage files
# attached.
#
# ## Expected layout
#
#   <root>/
#     Lifematerials-Kapok/
#       Lifematerials-Kapok.jpg       # macro (hero)
#       Lifematerials-Kapok-m1.jpg    # microscopy, position 0 (max zoom)
#       Lifematerials-Kapok-m2.jpg    # microscopy, position 1
#       Lifematerials-Kapok-m3.jpg    # microscopy, position 2
#       Lifematerials-Kapok.mp4       # video
#     Pyratex-Musa-1/
#       ...
#
# The folder name lowercased is matched against `Material#slug`. Files whose
# base name ends in `-m<N>` are classified as microscopies with position
# `N - 1`. Other image files are classified as the macro; video files
# (`.mp4`/`.mov`/`.webm`) as the video.
#
# The importer is idempotent: re-running it re-attaches each file on the same
# `(material, kind, position)` row rather than duplicating. Folders whose slug
# does not match any Material are skipped and reported in the result.
#
# Pre-processing (TIF/PNG → JPG, downscaling) is expected to happen upstream;
# the importer just uploads what it finds.
class MaterialAssetsImporter
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze

  VIDEO_EXTENSIONS = %w[.mp4 .mov .webm].freeze

  MICROSCOPY_SUFFIX = /-m(?<n>\d+)\z/i

  Result = Struct.new(:created, :updated, :skipped_missing_materials, :files_ignored, keyword_init: true) do
    def summary
      "#{created} created, #{updated} updated, " \
        "#{skipped_missing_materials.size} folder(s) skipped, " \
        "#{files_ignored.size} file(s) ignored"
    end
  end

  # @param root_path [String, Pathname] directory containing one subfolder per
  #   material (e.g. a local mirror of the Drive "Materials DB Images" folder).
  def initialize(root_path)
    @root = Pathname(root_path)
  end

  # Walks `@root`, attaches every recognised file, and returns a {Result}.
  #
  # @return [Result]
  def import!
    result = Result.new(
      created: 0, updated: 0,
      skipped_missing_materials: [], files_ignored: []
    )

    @root.children.select(&:directory?).sort.each do |folder|
      import_folder(folder, result)
    end

    result
  end

  private

  def import_folder(folder, result)
    slug = folder.basename.to_s.downcase
    material = Material.find_by(slug: slug)

    unless material
      result.skipped_missing_materials << slug
      return
    end

    folder.children.select(&:file?).sort.each do |file|
      import_file(file, material, result)
    end
  end

  def import_file(file, material, result)
    kind, position = classify(file)

    if kind.nil?
      result.files_ignored << file.basename.to_s
      return
    end

    upsert(material, kind, position, file, result)
  end

  def classify(file)
    ext  = file.extname.downcase
    stem = file.basename(file.extname).to_s

    if IMAGE_EXTENSIONS.include?(ext) && (match = stem.match(MICROSCOPY_SUFFIX))
      [ :microscopy, match[:n].to_i - 1 ]
    elsif IMAGE_EXTENSIONS.include?(ext)
      [ :macro, 0 ]
    elsif VIDEO_EXTENSIONS.include?(ext)
      [ :video, 0 ]
    end
  end

  def upsert(material, kind, position, file, result)
    asset = material.assets.find_or_initialize_by(kind: kind.to_s, position: position)
    was_new = asset.new_record?

    asset.file.attach(
      io:           File.open(file, "rb"),
      filename:     file.basename.to_s,
      content_type: Marcel::MimeType.for(Pathname(file), name: file.basename.to_s)
    )
    asset.save!

    was_new ? result.created += 1 : result.updated += 1
  end
end
