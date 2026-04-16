require "test_helper"

class ImageVariantsTest < ActiveSupport::TestCase
  test "exposes documented image presets" do
    assert_equal [ 200, 200 ], ImageVariants.transformations(:thumbnail)[:resize_to_limit]
    assert_equal [ 400, 300 ], ImageVariants.transformations(:card)[:resize_to_limit]
    assert_equal [ 1200, 1200 ], ImageVariants.transformations(:detail)[:resize_to_limit]
    assert_equal [ 1600, 900 ], ImageVariants.transformations(:hero)[:resize_to_limit]

    assert_equal({ width: 400, height: 300 }, ImageVariants.dimensions(:card))
  end

  test "rejects unknown presets" do
    error = assert_raises(ArgumentError) { ImageVariants.transformations(:unknown) }

    assert_includes error.message, "Unknown image variant"
  end
end
