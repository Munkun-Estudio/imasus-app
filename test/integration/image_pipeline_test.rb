require "test_helper"

class ImagePipelineTest < ActionDispatch::IntegrationTest
  setup do
    @previous_url_options = ActiveStorage::Current.url_options
    ActiveStorage::Current.url_options = { protocol: "http", host: "example.com" }
  end

  teardown do
    ActiveStorage::Current.url_options = @previous_url_options
  end

  test "uploads an image fixture and renders a lazy-loaded card variant" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )

    html = ApplicationController.render(
      inline: "<%= image_variant_tag(blob, preset: :card, alt: 'Sample image') %>",
      locals: { blob: blob }
    )

    assert_includes html, "<img"
    assert_includes html, "loading=\"lazy\""
    assert_includes html, "width=\"400\""
    assert_includes html, "height=\"300\""
    assert_match %r{/rails/active_storage/representations/}, html
  end
end
