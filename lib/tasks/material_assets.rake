require Rails.root.join("lib", "material_assets_importer")

namespace :material_assets do
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
