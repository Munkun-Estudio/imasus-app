require "test_helper"

class LibraryCatalogManifestTest < ActiveSupport::TestCase
  test "loads the complete IMASUS Library contract" do
    manifest = LibraryCatalog::Manifest.load(path: Rails.configuration.site.content.library)

    assert_equal [ "material" ], manifest.item_type_ids
    assert_equal %w[origin_type textile_imitating application], manifest.taxonomy_ids
    assert_equal 63, manifest.items.size
    assert_equal 30, manifest.taxonomies.sum { |taxonomy| taxonomy.terms.size }
  end

  test "loads the reusable non-Material example" do
    manifest = LibraryCatalog::Manifest.load(path: Rails.root.join("content/example-library.yml"))
    item = manifest.items.first

    assert_equal "worksheet", item.item_type
    assert_equal "Participants", item.fields.fetch("audience")
    assert_equal [ "reflection" ], item.taxonomies.fetch("topic")
    assert_equal "metadata", manifest.item_type("worksheet").field("audience").display
    assert manifest.item_type("worksheet").field("audience").card
    assert manifest.taxonomy("topic").filter
  end

  test "rejects unknown executable-looking keys" do
    payload = example_payload
    payload["items"].first["template"] = "<%= dangerous_call %>"

    error = assert_raises(LibraryCatalog::Manifest::Error) { load_payload(payload) }
    assert_includes error.message, "Unknown items[0] keys: template"
  end

  test "enforces required localized fallback values" do
    payload = example_payload
    instructions = payload["item_types"].first["fields"].last
    instructions["required"] = true
    payload["items"].first["fields"].delete("instructions")

    error = assert_raises(LibraryCatalog::Manifest::Error) { load_payload(payload) }
    assert_includes error.message, "fields.instructions is required"
  end

  test "enforces taxonomy cardinality" do
    payload = example_payload
    taxonomy = payload["taxonomies"].first
    taxonomy["cardinality"] = "one"
    taxonomy["terms"] << { "id" => "planning", "labels" => { "en" => "Planning" } }
    payload["items"].first["taxonomies"]["topic"] = %w[reflection planning]

    error = assert_raises(LibraryCatalog::Manifest::Error) { load_payload(payload) }
    assert_includes error.message, "accepts at most one term"
  end

  test "rejects unsafe link destinations" do
    payload = example_payload
    payload["items"].first["links"] = [
      { "label" => "Unsafe", "url" => "javascript:alert(1)" }
    ]

    error = assert_raises(LibraryCatalog::Manifest::Error) { load_payload(payload) }
    assert_includes error.message, "absolute HTTP or HTTPS URL"
  end

  test "requires bounded presentation hints" do
    payload = example_payload
    payload["item_types"].first["fields"].first.delete("display")

    error = assert_raises(LibraryCatalog::Manifest::Error) { load_payload(payload) }
    assert_includes error.message, "display must be one of"
  end

  test "rejects incompatible media presentation" do
    payload = example_payload
    payload["item_types"].first["media"] = [
      {
        "id" => "download",
        "kind" => "file",
        "multiple" => true,
        "placement" => "gallery",
        "cover" => false,
        "allowed_types" => [ "application/pdf" ],
        "max_bytes" => 1.megabyte
      }
    ]

    error = assert_raises(LibraryCatalog::Manifest::Error) { load_payload(payload) }
    assert_includes error.message, "placement is incompatible"
  end

  test "rejects asset paths that escape the manifest directory" do
    payload = example_payload
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
      { "role" => "cover", "path" => "../secret.png", "alt" => { "en" => "Cover" } }
    ]

    error = assert_raises(LibraryCatalog::Manifest::Error) { load_payload(payload) }
    assert_includes error.message, "must be relative"
  end

  private

  def example_payload
    YAML.safe_load_file(Rails.root.join("content/example-library.yml"), aliases: false)
  end

  def load_payload(payload)
    path = Rails.root.join("tmp", "library-manifest-#{SecureRandom.hex(4)}.yml")
    File.write(path, payload.to_yaml)
    LibraryCatalog::Manifest.load(path:)
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
