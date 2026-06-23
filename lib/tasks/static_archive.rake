require Rails.root.join("lib", "static_archive_exporter")

namespace :static_archive do
  desc "Export public IMASUS content for the static archive"
  task :export, [ :output_dir ] => :environment do |_, args|
    output_dir = args[:output_dir].presence || Rails.root.join("tmp", "static-archive")
    StaticArchiveExporter.new(output_dir: output_dir).export!
    puts "Exported static archive to #{Pathname(output_dir).expand_path}"
  end
end
