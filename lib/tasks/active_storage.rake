require Rails.root.join("lib", "active_storage_cors_configuration")

namespace :active_storage do
  desc "Apply the bucket CORS rule required for browser direct uploads"
  task configure_cors: :environment do
    config = ActiveStorageCorsConfiguration.new
    config.apply!

    puts "Applied Active Storage direct-upload CORS policy."
    puts "Bucket: #{ENV["AWS_S3_BUCKET"].presence || ENV["BUCKET_NAME"]}"
    puts "Origins: #{ActiveStorageCorsConfiguration.allowed_origins.join(", ")}"
  end
end
