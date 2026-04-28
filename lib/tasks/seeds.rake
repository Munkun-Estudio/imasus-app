namespace :db do
  namespace :seed do
    desc "Refresh repository-backed seed content, overwriting existing seeded rows"
    task refresh_content: :environment do
      ENV["SEED_OVERWRITE_CONTENT"] = "1"
      Rake::Task["db:seed"].invoke
    end
  end
end
