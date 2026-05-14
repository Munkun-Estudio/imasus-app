require "json"
require "net/http"
require "open3"
require "shellwords"
require "time"
require "uri"

class MediaPerformanceBenchmark
  DEFAULT_PATHS = [
    "/materials",
    "/materials/regenerated-wool"
  ].freeze

  CountResult = Struct.new(
    :img_tags,
    :video_tags,
    :source_tags,
    :representation_urls,
    :blob_urls,
    :lazy_images,
    keyword_init: true
  ) do
    def to_h
      {
        img_tags: img_tags,
        video_tags: video_tags,
        source_tags: source_tags,
        representation_urls: representation_urls,
        blob_urls: blob_urls,
        lazy_images: lazy_images
      }
    end
  end

  ResponseResult = Struct.new(
    :url,
    :status,
    :bytes,
    :ttfb,
    :total_time,
    :counts,
    :error,
    keyword_init: true
  ) do
    def to_h
      {
        url: url,
        status: status,
        bytes: bytes,
        ttfb: ttfb,
        total_time: total_time,
        counts: counts&.to_h,
        error: error
      }.compact
    end
  end

  def self.count_html(html)
    CountResult.new(
      img_tags: html.scan(/<img\b/i).size,
      video_tags: html.scan(/<video\b/i).size,
      source_tags: html.scan(/<source\b/i).size,
      representation_urls: html.scan(%r{/rails/active_storage/representations/}).size,
      blob_urls: html.scan(%r{/rails/active_storage/blobs/}).size,
      lazy_images: html.scan(/loading=["']lazy["']/i).size
    )
  end

  def initialize(base_url:, paths: DEFAULT_PATHS, lighthouse: true)
    @base_url = base_url.to_s.delete_suffix("/")
    @paths = paths
    @lighthouse = lighthouse
  end

  def run
    {
      generated_at: Time.now.utc.iso8601,
      base_url: @base_url,
      responses: @paths.map { |path| measure(path).to_h },
      lighthouse: lighthouse_results
    }
  end

  private

  def measure(path)
    url = absolute_url(path)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ttfb = nil

    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request) do |res|
        ttfb = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        body = +""
        res.read_body { |chunk| body << chunk }
        return ResponseResult.new(
          url: url,
          status: res.code.to_i,
          bytes: body.bytesize,
          ttfb: ttfb.round(4),
          total_time: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(4),
          counts: self.class.count_html(body)
        )
      end
    end
  rescue StandardError => e
    ResponseResult.new(url: url, error: "#{e.class}: #{e.message}")
  end

  def lighthouse_results
    return { skipped: "disabled" } unless @lighthouse
    return { skipped: "npx is not available" } unless command_available?("npx")

    @paths.first(2).to_h do |path|
      url = absolute_url(path)
      json, stderr, status = Open3.capture3(
        "npx", "--yes", "lighthouse", url,
        "--quiet",
        "--chrome-flags=--headless=new --no-sandbox",
        "--only-categories=performance",
        "--output=json"
      )

      result = if status.success?
        summarize_lighthouse(JSON.parse(json))
      else
        message = stderr.strip
        { skipped: message.empty? ? "lighthouse failed" : message }
      end

      [ url, result ]
    end
  end

  def summarize_lighthouse(report)
    audits = report.fetch("audits")
    {
      score: report.dig("categories", "performance", "score"),
      fcp_ms: audits.dig("first-contentful-paint", "numericValue")&.round,
      lcp_ms: audits.dig("largest-contentful-paint", "numericValue")&.round,
      speed_index_ms: audits.dig("speed-index", "numericValue")&.round,
      tbt_ms: audits.dig("total-blocking-time", "numericValue")&.round,
      cls: audits.dig("cumulative-layout-shift", "numericValue"),
      transfer_bytes: audits.dig("total-byte-weight", "numericValue"),
      requests: audits.dig("network-requests", "details", "items")&.size
    }
  end

  def absolute_url(path)
    path.start_with?("http") ? path : "#{@base_url}#{path}"
  end

  def command_available?(command)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
      File.executable?(File.join(dir, command))
    end
  end
end
