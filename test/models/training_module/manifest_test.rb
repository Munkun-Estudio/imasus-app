require "test_helper"
require "tmpdir"

class TrainingModule::ManifestTest < ActiveSupport::TestCase
  setup do
    @locales = Rails.configuration.site.locales
  end

  test "loads the IMASUS collection from the configured content directory" do
    manifest = TrainingModule::Manifest.load

    assert_equal 4, manifest.guides.size
    assert_equal %w[training-module toolkit case-study], manifest.sections.map(&:id)
    assert_equal %w[en es it el], manifest.about_documents.keys
  end

  test "rejects duplicate guide ids" do
    with_collection(guides: [ guide("first"), guide("first") ]) do |root|
      error = assert_raises(TrainingModule::Manifest::Error) { load_manifest(root) }
      assert_includes error.message, 'Duplicate guide id "first"'
    end
  end

  test "rejects missing documents with their manifest location" do
    with_collection do |root|
      File.delete(root.join("first/en/guide.md"))

      error = assert_raises(TrainingModule::Manifest::Error) { load_manifest(root) }
      assert_includes error.message, "Missing guide document"
      assert_includes error.message, "guides[0].translations.en.documents.guide"
    end
  end

  test "rejects unsafe document paths" do
    with_collection(document: "../outside.md") do |root|
      error = assert_raises(TrainingModule::Manifest::Error) { load_manifest(root) }
      assert_includes error.message, "must be a safe path"
    end
  end

  test "rejects missing cover assets" do
    with_collection(guides: [ guide("first").merge("cover" => "/missing-cover.png") ]) do |root|
      error = assert_raises(TrainingModule::Manifest::Error) { load_manifest(root) }
      assert_includes error.message, "Missing guide cover"
      assert_includes error.message, "guides[0].cover"
    end
  end

  test "rejects unsupported locales" do
    with_collection(translations: {
      "fr" => translation("first/fr/guide.md")
    }, document_locale: "fr") do |root|
      error = assert_raises(TrainingModule::Manifest::Error) { load_manifest(root) }
      assert_includes error.message, "Unsupported locales"
      assert_includes error.message, "fr"
    end
  end

  test "rejects malformed front matter and identifies the file" do
    with_collection(body: "---\ntitle: [broken\n---\nBody") do |root|
      error = assert_raises(TrainingModule::Manifest::Error) { load_manifest(root) }
      assert_includes error.message, "first/en/guide.md"
      assert_includes error.message, "Could not parse YAML"
    end
  end

  test "adding and removing a guide only changes manifest and content files" do
    with_collection(guides: [ guide("first"), guide("second") ], guide_ids: %w[first second]) do |root|
      assert_equal %w[first second], load_manifest(root).guides.map(&:id)

      write_manifest(root, guides: [ guide("second") ])
      FileUtils.rm_rf(root.join("first"))
      assert_equal [ "second" ], load_manifest(root).guides.map(&:id)
    end
  end

  private

  def with_collection(guides: nil, document: "first/en/guide.md", translations: nil,
                      document_locale: "en", body: "---\ntitle: First\n---\nBody", guide_ids: [ "first" ])
    Dir.mktmpdir do |directory|
      root = Pathname(directory)
      guide_ids.each do |id|
        path = root.join(id, document_locale, "guide.md")
        FileUtils.mkdir_p(path.dirname)
        path.write(body)
      end
      root.join("en").mkpath
      root.join("en/about.md").write("---\ntitle: About\n---\nAbout")
      write_manifest(root, guides: guides || [ guide("first", document:, translations:) ])
      yield root
    end
  end

  def write_manifest(root, guides:)
    root.join("manifest.yml").write({
      "version" => 1,
      "about" => { "en" => "en/about.md" },
      "sections" => [ { "id" => "guide", "labels" => @locales.available.to_h { |locale| [ locale, "Guide" ] } } ],
      "guides" => guides
    }.to_yaml)
  end

  def guide(id, document: "#{id}/en/guide.md", translations: nil)
    {
      "id" => id,
      "published" => true,
      "cover" => "/icon.svg",
      "translations" => translations || { "en" => translation(document) }
    }
  end

  def translation(document)
    { "title" => "First", "summary" => "Summary", "documents" => { "guide" => document } }
  end

  def load_manifest(root)
    TrainingModule::Manifest.load(root:, locales: @locales)
  end
end
