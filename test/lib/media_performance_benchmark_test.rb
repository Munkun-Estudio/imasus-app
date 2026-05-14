require "minitest/autorun"
require_relative "../../lib/media_performance_benchmark"

class MediaPerformanceBenchmarkTest < Minitest::Test
  def test_count_html_reports_media_and_active_storage_url_counts
    html = <<~HTML
      <img src="/rails/active_storage/representations/redirect/a" loading="lazy">
      <img src="/rails/active_storage/blobs/redirect/b" loading="eager">
      <video><source src="/rails/active_storage/blobs/redirect/c"></video>
    HTML

    counts = MediaPerformanceBenchmark.count_html(html)

    assert_equal 2, counts.img_tags
    assert_equal 1, counts.video_tags
    assert_equal 1, counts.source_tags
    assert_equal 1, counts.representation_urls
    assert_equal 2, counts.blob_urls
    assert_equal 1, counts.lazy_images
  end
end
