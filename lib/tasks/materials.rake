require Rails.root.join("lib", "materials_source_parser")

namespace :materials do
  desc "Reconcile docs/materials-db.md into db/seeds/materials.yml"
  task :reconcile_seed do
    source_path = Rails.root.join("docs", "materials-db.md")
    target_path = Rails.root.join("db", "seeds", "materials.yml")

    entries = MaterialsSourceParser.new(File.read(source_path)).entries
    File.write(target_path, entries.to_yaml(line_width: -1))

    puts "Wrote #{entries.size} materials to #{target_path.relative_path_from(Rails.root)}"
  end
end
