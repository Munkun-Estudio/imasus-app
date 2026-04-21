require Rails.root.join("lib", "material_assets_importer")
require Rails.root.join("lib", "material_assets_preprocessor")

namespace :material_assets do
  desc "Prepare material media for web import (images -> JPG, resized; videos copied as-is)"
  task :prepare, [ :source, :output, :macro_long_edge, :microscopy_long_edge, :quality ] do |_, args|
    source = args[:source] or abort(
      "Usage: bin/rake \"material_assets:prepare[/path/to/source,/path/to/output,3600,2400,90]\""
    )

    output = args[:output] || Rails.root.join("tmp", "material-assets-prepared")

    result = MaterialAssetsPreprocessor.new(
      source,
      output_path:          output,
      macro_long_edge:      args[:macro_long_edge] || MaterialAssetsPreprocessor::DEFAULT_MACRO_LONG_EDGE,
      microscopy_long_edge: args[:microscopy_long_edge] || MaterialAssetsPreprocessor::DEFAULT_MICROSCOPY_LONG_EDGE,
      quality:              args[:quality] || MaterialAssetsPreprocessor::DEFAULT_JPEG_QUALITY
    ).prepare!

    puts "Prepared media in #{Pathname(output).expand_path}"
    puts result.summary
    unless result.files_ignored.empty?
      puts "\nIgnored files (unknown extension or naming):"
      result.files_ignored.each { |f| puts "  - #{f}" }
    end
  rescue ArgumentError => e
    abort(e.message)
  end

  desc "Import material media from a local folder that mirrors the Drive layout"
  task :import, [ :path ] => :environment do |_, args|
    path = args[:path] or abort("Usage: bin/rake 'material_assets:import[/path/to/Materials DB Images]'")

    result = MaterialAssetsImporter.new(path).import!

    puts result.summary
    unless result.skipped_missing_materials.empty?
      puts "\nSkipped folders (no matching Material slug):"
      result.skipped_missing_materials.each { |s| puts "  - #{s}" }
    end
    unless result.files_ignored.empty?
      puts "\nIgnored files (unknown extension or naming):"
      result.files_ignored.each { |f| puts "  - #{f}" }
    end
  end
end
