require "test_helper"
require Rails.root.join("lib", "static_archive_exporter")

class StaticArchiveExporterTest < ActiveSupport::TestCase
  SAMPLE_IMAGE = Rails.root.join("test/fixtures/files/sample-image.png")

  setup do
    @output_dir = Rails.root.join("tmp", "static-archive-exporter-test-#{Process.pid}")
    FileUtils.rm_rf(@output_dir)
    @workshop = Workshop.create!(slug: "archive-workshop", title_translations: { "en" => "Archive workshop" }, description_translations: { "en" => "Public" }, location: "Madrid", starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 1, 2))
  end

  teardown { FileUtils.rm_rf(@output_dir) }

  test "exports only active published projects and ordered material assets" do
    published = create_project("Published", "published")
    draft = create_project("Draft", "draft")
    disabled = create_project("Disabled", "published")
    disabled.update!(disabled_at: Time.current)

    material = Material.create!(trade_name: "Archive material", availability_status: "commercial", description_translations: { "en" => "Description" })
    [ 1, 0 ].each do |position|
      asset = MaterialAsset.new(material: material, kind: "macro", position: position)
      asset.file.attach(io: SAMPLE_IMAGE.open, filename: "macro-#{position}.png", content_type: "image/png")
      asset.save!
    end

    export!

    projects = read_json("projects.json")
    assert_equal [ published.slug ], projects.map { |project| project.fetch("slug") }
    assert_not_includes projects.map { |project| project.fetch("slug") }, draft.slug
    assert_not_includes projects.map { |project| project.fetch("slug") }, disabled.slug

    assets = read_json("materials.json").find { |entry| entry.fetch("slug") == material.slug }.fetch("assets")
    assert_equal [ 0, 1 ], assets.map { |asset| asset.fetch("position") }
    assert read_json("assets.json").all? { |asset| asset.fetch("url").start_with?("https://assets.example.test/") }
  end

  test "refuses a non-empty destination" do
    @output_dir.mkpath
    @output_dir.join("existing.txt").write("keep")

    assert_raises(ArgumentError) { export! }
  end

  test "rejects Rails Active Storage URLs" do
    material = Material.create!(trade_name: "URL guard", availability_status: "commercial", description_translations: { "en" => "Description" })
    asset = MaterialAsset.new(material: material, kind: "macro", position: 0)
    asset.file.attach(io: SAMPLE_IMAGE.open, filename: "guard.png", content_type: "image/png")
    asset.save!

    error = assert_raises(RuntimeError) do
      StaticArchiveExporter.new(output_dir: @output_dir, asset_url: ->(_) { "https://app.imasus.eu/rails/active_storage/blobs/redirect" }).export!
    end
    assert_match "Rails Active Storage URL", error.message
  end

  test "rewrites Action Text attachment URLs through the asset manifest" do
    project = create_project("Embedded media", "published")
    blob = ActiveStorage::Blob.create_and_upload!(io: SAMPLE_IMAGE.open, filename: "inline.png", content_type: "image/png")
    figure = %(<figure data-trix-attachment="#{ERB::Util.html_escape({ sgid: blob.attachable_sgid, contentType: "image/png", filename: "inline.png", filesize: blob.byte_size }.to_json)}"></figure>)
    project.update!(process_summary: "<p>Public image</p>#{figure}")

    export!

    summary = read_json("projects.json").find { |entry| entry.fetch("slug") == project.slug }.fetch("process_summary")
    assert_includes summary.fetch("html"), "https://assets.example.test/#{blob.key}"
    assert_includes summary.fetch("html"), "data-static-asset-id=\"blob-#{blob.id}\""
    assert_not_includes summary.fetch("html"), "/rails/active_storage/"
    assert_equal [ "blob-#{blob.id}" ], summary.fetch("asset_ids")
  end

  private

  def create_project(title, status)
    project = Project.new(workshop: @workshop, title: title, language: "en", status: status)
    if status == "published"
      project.process_summary = "Public summary"
      project.hero_image.attach(io: SAMPLE_IMAGE.open, filename: "hero.png", content_type: "image/png")
    end
    project.save!
    project
  end

  def export!
    StaticArchiveExporter.new(output_dir: @output_dir, asset_url: ->(blob) { "https://assets.example.test/#{blob.key}" }).export!
  end

  def read_json(filename)
    JSON.parse(@output_dir.join(filename).read)
  end
end
