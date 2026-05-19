require "pathname"
require "set"
require_relative "material_assets_naming"
require_relative "material_assets_preprocessor"
require_relative "material_assets_slug_resolver"

# Compares a local partner-media import tree with the Material catalogue.
#
# The audit is intentionally filesystem-first: partner folders are the current
# source of truth for which materials have media, and the resulting missing
# list is what curators review before pruning no-picture materials.
class MaterialAssetsAuditor
  Result = Struct.new(
    :materials_without_import_media,
    :folders_without_material,
    :folders_with_multiple_macros,
    :folders_with_multiple_videos,
    keyword_init: true
  ) do
    def summary
      "#{materials_without_import_media.size} material(s) without import media, " \
        "#{folders_without_material.size} import folder(s) without material, " \
        "#{folders_with_multiple_macros.size} folder(s) with multiple macro photos, " \
        "#{folders_with_multiple_videos.size} folder(s) with multiple videos"
    end
  end

  def initialize(root_path, expected_materials: nil)
    @root = Pathname(root_path)
    @expected_materials = expected_materials
  end

  def audit
    import_rows = import_folder_rows
    slugs_with_media = import_rows.select { |row| row[:image_count].positive? }.map { |row| row[:slug] }.to_set
    material_slugs = expected_materials
    material_slug_set = material_slugs.map(&:first).to_set

    Result.new(
      materials_without_import_media: material_slugs.reject { |slug, _| slugs_with_media.include?(slug) },
      folders_without_material:       import_rows.reject { |row| material_slug_set.include?(row[:slug]) },
      folders_with_multiple_macros:   import_rows.select { |row| row[:macro_count] > 1 },
      folders_with_multiple_videos:   import_rows.select { |row| row[:video_count] > 1 }
    )
  end

  private

  def import_folder_rows
    @root.children.select(&:directory?).sort.map do |folder|
      counts = asset_counts(folder)
      {
        folder:      folder.basename.to_s,
        slug:        normalized_slug(folder.basename.to_s),
        image_count: counts.fetch(:macro, 0) + counts.fetch(:microscopy, 0),
        macro_count: counts.fetch(:macro, 0),
        video_count: counts.fetch(:video, 0),
        videos:      videos_for(folder)
      }
    end
  end

  def expected_materials
    @expected_materials || Material.order(:position).pluck(:slug, :trade_name)
  end

  def asset_counts(folder)
    folder.children.select(&:file?).each_with_object(Hash.new(0)) do |file, counts|
      kind, = MaterialAssetsNaming.classify(
        file,
        image_extensions: MaterialAssetsPreprocessor::SOURCE_IMAGE_EXTENSIONS,
        material_stem:    folder.basename.to_s
      )
      counts[kind] += 1 if kind
    end
  end

  def normalized_slug(folder_name)
    MaterialAssetsSlugResolver.call(folder_name)
  end

  def videos_for(folder)
    folder.children.select(&:file?).select do |file|
      MaterialAssetsNaming::VIDEO_EXTENSIONS.include?(file.extname.downcase)
    end.map { |file| file.basename.to_s }.sort
  end
end
