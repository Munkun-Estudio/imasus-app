require Rails.root.join("lib", "materials_source_parser")
require Rails.root.join("lib", "materials_exporter")
require Rails.root.join("lib", "material_confirmed_variants")

namespace :materials do
  desc "Reconcile docs/materials-db.md into db/seeds/materials.yml"
  task :reconcile_seed do
    source_path = Rails.root.join("docs", "materials-db.md")
    target_path = Rails.root.join("db", "seeds", "materials.yml")

    entries = MaterialsSourceParser.new(File.read(source_path)).entries
    File.write(target_path, entries.to_yaml(line_width: -1))

    puts "Wrote #{entries.size} materials to #{target_path.relative_path_from(Rails.root)}"
  end

  desc "Export current material catalogue text and metadata to JSON"
  task :export, [ :path ] => :environment do |_, args|
    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    path = Pathname(args[:path].presence || Rails.root.join("tmp", "materials-export-#{timestamp}.json"))
    path.dirname.mkpath

    payload = MaterialsExporter.new.export
    path.write(JSON.pretty_generate(payload))

    puts "Exported #{payload[:count]} materials to #{path.expand_path}"
  end

  desc "Create confirmed numbered material variants from existing DB rows; pass APPLY to mutate"
  task :materialize_confirmed_variants, [ :confirm ] => :environment do |_, args|
    apply = args[:confirm] == "APPLY"
    result = MaterialConfirmedVariants.new(apply: apply).call

    puts result.summary
    puts apply ? "Applied confirmed variants." : "Dry run only. Re-run with APPLY to mutate production data."

    unless result.changes.empty?
      puts "\nChanges:"
      result.changes.each { |change| puts "  - #{change}" }
    end

    unless result.skips.empty?
      puts "\nSkipped:"
      result.skips.each { |skip| puts "  - #{skip}" }
    end

    unless result.missing.empty?
      puts "\nMissing sources:"
      result.missing.each { |missing| puts "  - #{missing}" }
    end

    unless result.conflicts.empty?
      puts "\nConflicts:"
      result.conflicts.each { |conflict| puts "  - #{conflict}" }
    end
  end
end
