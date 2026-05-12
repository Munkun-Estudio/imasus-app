require "test_helper"
require Rails.root.join("lib", "active_storage_cors_configuration")

class ActiveStorageCorsConfigurationTest < ActiveSupport::TestCase
  class FakeS3Client
    attr_reader :request

    def put_bucket_cors(request)
      @request = request
    end
  end

  test "applies cors policy required by Active Storage direct uploads" do
    client = FakeS3Client.new
    configuration = ActiveStorageCorsConfiguration.new(
      bucket: "imasus-test",
      allowed_origins: [ "https://app.imasus.eu" ],
      client: client
    )

    configuration.apply!

    assert_equal "imasus-test", client.request[:bucket]
    rule = client.request.dig(:cors_configuration, :cors_rules).first
    assert_equal [ "https://app.imasus.eu" ], rule[:allowed_origins]
    assert_equal [ "PUT" ], rule[:allowed_methods]
    assert_includes rule[:allowed_headers], "Content-Type"
    assert_includes rule[:allowed_headers], "Content-MD5"
    assert_includes rule[:allowed_headers], "Content-Disposition"
    assert_includes rule[:allowed_headers], "Content-Length"
    assert_equal [ "ETag" ], rule[:expose_headers]
  end

  test "requires a bucket name" do
    configuration = ActiveStorageCorsConfiguration.new(
      bucket: nil,
      allowed_origins: [ "https://app.imasus.eu" ],
      client: FakeS3Client.new
    )

    error = assert_raises(ArgumentError) { configuration.apply! }
    assert_equal "Missing AWS_S3_BUCKET or BUCKET_NAME", error.message
  end
end
