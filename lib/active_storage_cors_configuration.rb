require "aws-sdk-s3"

# Applies the CORS rule needed by Active Storage direct uploads against the
# S3-compatible production bucket.
class ActiveStorageCorsConfiguration
  DEFAULT_ALLOWED_ORIGINS = [ "https://app.imasus.eu", "https://imasus-app.fly.dev" ].freeze
  DEFAULT_ALLOWED_HEADERS = [
    "Content-Type",
    "Content-MD5",
    "Content-Disposition",
    "Content-Length"
  ].freeze

  def initialize(
    bucket: ENV["AWS_S3_BUCKET"].presence || ENV["BUCKET_NAME"],
    allowed_origins: self.class.allowed_origins,
    client: self.class.s3_client
  )
    @bucket = bucket
    @allowed_origins = allowed_origins
    @client = client
  end

  def apply!
    raise ArgumentError, "Missing AWS_S3_BUCKET or BUCKET_NAME" if bucket.blank?
    raise ArgumentError, "At least one CORS origin is required" if allowed_origins.empty?

    client.put_bucket_cors(
      bucket: bucket,
      cors_configuration: {
        cors_rules: [
          {
            allowed_origins: allowed_origins,
            allowed_methods: [ "PUT" ],
            allowed_headers: DEFAULT_ALLOWED_HEADERS,
            expose_headers: [ "ETag" ],
            max_age_seconds: 3600
          }
        ]
      }
    )
  end

  def self.allowed_origins
    ENV.fetch("ACTIVE_STORAGE_CORS_ORIGINS", DEFAULT_ALLOWED_ORIGINS.join(","))
       .split(",")
       .map(&:strip)
       .compact_blank
  end

  def self.s3_client
    options = {
      region: ENV.fetch("AWS_REGION", "auto"),
      access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
      secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY")
    }
    options[:endpoint] = ENV["AWS_ENDPOINT_URL_S3"] if ENV["AWS_ENDPOINT_URL_S3"].present?

    Aws::S3::Client.new(**options)
  end

  private

  attr_reader :bucket, :allowed_origins, :client
end
