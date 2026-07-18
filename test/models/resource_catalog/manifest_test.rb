require "test_helper"
require "tmpdir"

class ResourceCatalog::ManifestTest < ActiveSupport::TestCase
  test "loads configured category labels, entry order, localized bodies, and publication state" do
    manifest = ResourceCatalog.prompts

    assert_equal %w[material design system business], manifest.category_ids
    assert_equal "Diseño", manifest.category("design").label(locale: :es, locales: Rails.configuration.site.locales)
    assert_equal (1..10).map { |number| "C#{number}" }, manifest.entries.map(&:id)
    assert manifest.entries.first.published
    assert_equal [], manifest.entries.first.tags
    assert_includes manifest.entries.first.translations.dig("es", "question"), "materias primas"
  end

  test "loads explicit glossary ids instead of deriving them from English terms" do
    manifest = ResourceCatalog.glossary

    assert_equal "imagineering", manifest.entries.first.id
    assert_equal "Imagineering", manifest.entries.first.translations.dig("en", "term")
  end

  test "rejects duplicate ids case-insensitively" do
    payload = valid_payload
    duplicate = payload["entries"].first.deep_dup
    duplicate["id"] = "FIRST"
    payload["entries"] << duplicate

    error = load_error(payload)
    assert_includes error.message, "Duplicate entry id"
  end

  test "rejects unknown category references" do
    payload = valid_payload
    payload["entries"].first["category"] = "missing"

    error = load_error(payload)
    assert_includes error.message, "references unknown category"
  end

  test "rejects unsupported locales" do
    payload = valid_payload
    payload["entries"].first["translations"]["fr"] = { "question" => "Question", "description" => "Body" }

    error = load_error(payload)
    assert_includes error.message, "Unsupported locales"
  end

  test "requires localized category labels for all configured locales" do
    payload = valid_payload
    payload["categories"].first["labels"].delete("el")

    error = load_error(payload)
    assert_includes error.message, "Missing categories[0].labels entries: el"
  end

  test "requires source-locale content" do
    payload = valid_payload
    payload["entries"].first["translations"].delete(Rails.configuration.site.locales.fallback)

    error = load_error(payload)
    assert_includes error.message, "translations.en is required"
  end

  test "rejects malformed YAML with the manifest path" do
    Dir.mktmpdir do |directory|
      path = Pathname(directory).join("broken.yml")
      path.write("entries: [broken")

      error = assert_raises(ResourceCatalog::Manifest::Error) { load_prompts(path) }
      assert_includes error.message, path.to_s
    end
  end

  private

  def valid_payload
    locales = Rails.configuration.site.locales.available
    {
      "version" => 1,
      "resource" => "prompts",
      "categories" => [ {
        "id" => "general",
        "labels" => locales.to_h { |locale| [ locale, "General" ] }
      } ],
      "entries" => [ {
        "id" => "first",
        "category" => "general",
        "tags" => [ "workshop" ],
        "published" => true,
        "asset" => nil,
        "translations" => {
          Rails.configuration.site.locales.fallback => {
            "question" => "A question?",
            "description" => "A description."
          }
        }
      } ]
    }
  end

  def load_error(payload)
    Dir.mktmpdir do |directory|
      path = Pathname(directory).join("manifest.yml")
      path.write(payload.to_yaml)
      return assert_raises(ResourceCatalog::Manifest::Error) { load_prompts(path) }
    end
  end

  def load_prompts(path)
    ResourceCatalog::Manifest.load(
      path:,
      resource: "prompts",
      fields: { "question" => :string, "description" => :string }
    )
  end
end
