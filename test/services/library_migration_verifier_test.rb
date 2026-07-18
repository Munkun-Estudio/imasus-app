require "test_helper"

class LibraryMigrationVerifierTest < ActiveSupport::TestCase
  test "verifies the synchronized IMASUS catalogue and detects divergence" do
    LibraryItem.seed_from_manifest!(overwrite: true)

    result = LibraryMigrationVerifier.new.call
    assert result.success?, result.errors.join("\n")
    assert_equal 63, result.counts.fetch(:published_items)
    assert_equal 30, result.counts.fetch(:terms)

    item = Material.first
    item.update_column(:title_translations, { "en" => "Diverged title" })

    result = LibraryMigrationVerifier.new.call
    assert_not result.success?
    assert result.errors.any? { |error| error.include?("title.en") }
  end
end
