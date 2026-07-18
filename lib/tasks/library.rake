namespace :library do
  desc "Verify the generic Library migration before retiring legacy storage"
  task verify_migration: :environment do
    result = LibraryMigrationVerifier.new.verify!
    result.counts.each { |name, count| puts "#{name}: #{count}" }
    puts "Library migration verified."
  end
end
