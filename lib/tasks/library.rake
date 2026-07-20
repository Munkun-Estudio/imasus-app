namespace :library do
  desc "Preview or apply the idempotent Library manifest sync (APPLY=1 to write)"
  task sync: :environment do
    apply = ENV["APPLY"] == "1"
    result = LibrarySynchronizer.new.call(apply:)
    result.changes.each do |change|
      puts "#{change.action.ljust(7)} #{change.resource.ljust(14)} #{change.id}"
    end
    puts "Mode: #{result.mode}"
    puts(result.counts.any? ? result.counts.map { |action, count| "#{action}=#{count}" }.join(" ") : "No changes.")
    puts "Run with APPLY=1 to apply this plan." unless apply
  end

  desc "Verify the generic Library migration before retiring legacy storage"
  task verify_migration: :environment do
    result = LibraryMigrationVerifier.new.verify!
    result.counts.each { |name, count| puts "#{name}: #{count}" }
    puts "Library migration verified."
  end
end
