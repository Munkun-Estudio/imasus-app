require "test_helper"
require "fileutils"
require "tmpdir"

class LibrarySynchronizerTest < ActiveSupport::TestCase
  setup do
    @directory = Pathname(Dir.mktmpdir("library-sync-", Rails.root.join("tmp")))
    FileUtils.cp Rails.root.join("test/fixtures/files/sample-image.png"), @directory.join("cover.png")
  end

  teardown do
    FileUtils.rm_rf(@directory)
  end

  test "dry run reports additions without changing records" do
    manifest = write_manifest(payload_with_asset)

    assert_no_difference [ "LibraryItem.count", "LibraryItemAsset.count" ] do
      result = LibrarySynchronizer.new(manifest:).call
      assert_equal "dry-run", result.mode
      assert result.changes.any? { |change| change.action == "add" && change.resource == "item" }
      assert result.changes.any? { |change| change.action == "add" && change.resource == "asset" }
    end
  end

  test "confirmed sync is idempotent and attaches validated local media" do
    manifest = write_manifest(payload_with_asset)
    synchronizer = LibrarySynchronizer.new(manifest:)

    synchronizer.call(apply: true)
    item = LibraryItem.find_by!(slug: "first-reflection")
    asset = item.assets.first

    assert asset.file.attached?
    assert_equal "cover", asset.role
    assert_equal "A notebook on a table", asset.alt_text
    assert_empty LibrarySynchronizer.new(manifest:).call.changes
  end

  test "missing manifest assets are retired without purging their files" do
    original = write_manifest(payload_with_asset)
    LibrarySynchronizer.new(manifest: original).call(apply: true)
    asset = LibraryItem.find_by!(slug: "first-reflection").assets.first
    blob_id = asset.file.blob.id

    without_asset = payload_with_asset
    without_asset["items"].first["assets"] = []
    updated = write_manifest(without_asset, name: "without-asset.yml")
    result = LibrarySynchronizer.new(manifest: updated).call(apply: true)

    assert result.changes.any? { |change| change.action == "retire" && change.resource == "asset" }
    assert asset.reload.retired_at?
    assert asset.file.attached?
    assert ActiveStorage::Blob.exists?(blob_id)
  end

  test "content updates refresh bookmark labels while preserving bookmark URLs" do
    original = write_manifest(payload_with_asset)
    LibrarySynchronizer.new(manifest: original).call(apply: true)
    user = User.create!(name: "Reader", email: "library-sync@example.test", password: "password-long-enough", role: :participant)
    bookmark = Bookmark.create!(
      user:,
      bookmarkable_type: "LibraryItem",
      resource_key: "first-reflection",
      label: "Old title",
      url: "/materials/first-reflection"
    )

    changed_payload = payload_with_asset
    changed_payload["items"].first["translations"]["en"]["title"] = "Updated reflection"
    changed = write_manifest(changed_payload, name: "changed.yml")
    LibrarySynchronizer.new(manifest: changed).call(apply: true)

    assert_equal "Updated reflection", bookmark.reload.label
    assert_equal "/materials/first-reflection", bookmark.url
  end

  private

  def payload_with_asset
    payload = YAML.safe_load_file(Rails.root.join("content/example-library.yml"), aliases: false)
    payload["item_types"].first["media"] = [
      {
        "id" => "cover",
        "kind" => "image",
        "multiple" => false,
        "placement" => "gallery",
        "cover" => true,
        "allowed_types" => [ "image/png" ],
        "max_bytes" => 1.megabyte
      }
    ]
    payload["items"].first["assets"] = [
      { "role" => "cover", "path" => "cover.png", "alt" => { "en" => "A notebook on a table" } }
    ]
    payload
  end

  def write_manifest(payload, name: "library.yml")
    path = @directory.join(name)
    File.write(path, payload.to_yaml)
    LibraryCatalog::Manifest.load(path:)
  end
end
