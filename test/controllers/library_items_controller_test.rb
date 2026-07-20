require "test_helper"

class LibraryItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    LibraryItem.seed_from_manifest!(overwrite: true)
  end

  test "generic Library index renders manifest labels, cards, and filters" do
    get library_url

    assert_response :success
    assert_select "[data-library-item]", count: MaterialsController::BATCH_SIZE
    assert_select "[data-taxonomy='origin_type']"
    assert_select "h1", text: ResourceModuleRegistry.current.fetch(:library).label(
      locale: I18n.locale,
      locales: Rails.configuration.site.locales
    )
  end

  test "generic Library filters items by configured taxonomy" do
    get library_url(origin_type: "plants")

    assert_response :success
    assert_select "meta[name='robots'][content='noindex,nofollow']"
    rendered = css_select("[data-library-item]").map { |node| node["data-library-item"] }
    expected = LibraryTaxonomyTerm.find_by!(taxonomy_key: "origin_type", slug: "plants").library_items.pluck(:slug)
    assert_empty rendered - expected
  end

  test "generic Library detail renders ordered manifest fields and stable bookmark identity" do
    item = LibraryItem.published.find_by!(slug: "pyratex-musa-1")
    password = "password-long-enough"
    user = User.create!(name: "Reader", email: "library-reader@example.test", password:, role: :participant)
    post session_url, params: { email: user.email, password: }

    get library_item_url(item)

    assert_response :success
    assert_select "h1", text: item.title
    assert_select "[data-field='interesting_properties']"
    assert_select "input[name='bookmark[bookmarkable_type]'][value='LibraryItem']"
    assert_select "input[name='bookmark[resource_key]'][value='#{item.slug}']"
  end

  test "retired Library items stay addressable but are not listed" do
    item = LibraryItem.published.first
    item.update_columns(published: false)

    get library_url
    assert_select "[data-library-item='#{item.slug}']", count: 0

    get library_item_url(item)
    assert_response :success
    assert_select "meta[name='robots'][content='noindex,nofollow']"
    assert_select "[role='status']", text: /no longer listed/i
  end

  test "generic Library does not turn stale unsafe stored links into destinations" do
    item = LibraryItem.published.first
    item.update_columns(links: [ { "label" => "Unsafe legacy link", "url" => "javascript:alert(1)" } ])

    get library_item_url(item)

    assert_response :success
    assert_select "a[href^='javascript:']", count: 0
    assert_includes response.body, "Unsafe legacy link"
  end

  test "a non-Material item type renders from its manifest without application code" do
    manifest = LibraryCatalog::Manifest.load(path: Rails.root.join("content/example-library.yml"))
    LibraryItem.seed_from_manifest!(manifest:, overwrite: true)
    previous_manifest = LibraryCatalog.instance_variable_get(:@current)
    LibraryCatalog.instance_variable_set(:@current, manifest)

    get library_url

    assert_response :success
    assert_select "[data-library-item='first-reflection']"
    assert_select "[data-library-item='first-reflection']", text: /Worksheet/
    assert_select "[data-library-item='first-reflection']", text: /Participants/

    get library_item_url("first-reflection")
    assert_response :success
    assert_select "[data-field='instructions']", text: /Note one decision/
    assert_select "[data-taxonomy='topic']", text: /Reflection/
  ensure
    LibraryCatalog.instance_variable_set(:@current, previous_manifest)
  end
end
