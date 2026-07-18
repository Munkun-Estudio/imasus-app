require "test_helper"

class ResourceModuleRegistryTest < ActiveSupport::TestCase
  test "declares stable metadata and configured labels for every supported module" do
    registry = ResourceModuleRegistry.current

    assert_equal %i[library guides prompts glossary], registry.all.map(&:key)
    assert_equal %w[LibraryItem TrainingModule Challenge GlossaryTerm],
                 registry.all.map(&:bookmark_type)
    assert_equal %w[LibraryItem Material], registry.fetch(:library).bookmark_types
    assert_equal :materials_path, registry.fetch(:library).route_helper
    assert_equal({ type: :filesystem, identifier: "content.guides" },
                 registry.fetch(:guides).content_source)
    assert_equal "Materiales",
                 registry.fetch(:library).label(locale: :es, locales: Rails.configuration.site.locales)
  end

  test "minimal profile enables only its configured module" do
    site = SiteConfig.load(root: Rails.root, env: { "APP_PROFILE" => "minimal" })
    registry = ResourceModuleRegistry.new(site)

    assert_equal [ :guides ], registry.enabled.map(&:key)
    assert_equal [ "TrainingModule" ], registry.enabled_bookmark_types
    assert_equal "Guides",
                 registry.fetch(:guides).label(locale: :en, locales: site.locales)
  end

  test "validates enabled module dependencies" do
    site = SiteConfig.load(root: Rails.root, env: { "APP_PROFILE" => "minimal" })
    definitions = ResourceModuleRegistry::DEFINITIONS.transform_values(&:dup)
    definitions[:guides] = definitions.fetch(:guides).merge(dependencies: [ :glossary ])

    error = assert_raises(ArgumentError) do
      ResourceModuleRegistry.new(site, definitions:)
    end

    assert_includes error.message, "guides requires enabled module glossary"
  end

  test "rejects unknown dependency declarations" do
    definitions = ResourceModuleRegistry::DEFINITIONS.transform_values(&:dup)
    definitions[:library] = definitions.fetch(:library).merge(dependencies: [ :missing ])

    error = assert_raises(ArgumentError) do
      ResourceModuleRegistry.new(Rails.configuration.site, definitions:)
    end

    assert_includes error.message, "unknown dependency missing"
  end
end
