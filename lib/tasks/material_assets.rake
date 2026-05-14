require Rails.root.join("lib", "material_assets_importer")
require Rails.root.join("lib", "material_assets_preprocessor")
require "open3"
require "tempfile"

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
    ActiveJob::Base.queue_adapter = :inline
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

  desc "Warm common image variants for material and log-entry media"
  task warm_variants: :environment do
    presets_by_kind = {
      "macro" => %i[card hero thumbnail],
      "microscopy" => %i[card hero thumbnail]
    }

    material_count = 0
    MaterialAsset.includes(file_attachment: :blob).find_each do |asset|
      next unless asset.file.attached? && asset.file.image?

      Array(presets_by_kind[asset.kind]).each do |preset|
        ImageVariants.variant_for(asset.file, preset).processed
        material_count += 1
      end
    end

    log_count = 0
    ActiveStorage::Attachment.where(record_type: "LogEntry", name: "media").includes(:blob).find_each do |attachment|
      next unless attachment.image?

      ImageVariants.variant_for(attachment, :log_entry_thumbnail).processed
      log_count += 1
    end

    puts "Warmed #{material_count} material variant(s) and #{log_count} log-entry variant(s)."
  end

  desc "Generate poster attachments for material video assets using ffmpeg"
  task generate_video_posters: :environment do
    unless ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "ffmpeg")) }
      abort("ffmpeg is not available on PATH")
    end

    generated = 0
    skipped = 0

    MaterialAsset.video.includes(file_attachment: :blob, poster_attachment: :blob).find_each do |asset|
      if asset.poster.attached? || !asset.file.attached?
        skipped += 1
        next
      end

      Tempfile.create([ "material-video-poster-#{asset.id}", ".jpg" ]) do |file|
        file.close
        asset.file.open do |video|
          _stdout, stderr, status = Open3.capture3(
            "ffmpeg",
            "-y",
            "-ss", "00:00:01",
            "-i", video.path,
            "-frames:v", "1",
            "-vf", "scale='min(1280,iw)':-2",
            file.path
          )
          raise "ffmpeg failed for MaterialAsset #{asset.id}: #{stderr.strip}" unless status.success?
        end

        asset.poster.attach(
          io: File.open(file.path, "rb"),
          filename: "material-video-#{asset.id}-poster.jpg",
          content_type: "image/jpeg"
        )
        generated += 1
      end
    end

    puts "Generated #{generated} poster(s), skipped #{skipped} material video asset(s)."
  end
end
