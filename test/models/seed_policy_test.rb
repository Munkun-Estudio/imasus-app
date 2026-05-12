require "test_helper"

class SeedPolicyTest < ActiveSupport::TestCase
  def with_env(values)
    previous = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "overwrite? reads global and scoped seed flags" do
    with_env("SEED_OVERWRITE_CONTENT" => nil, "SEED_WORKSHOPS" => nil) do
      assert_not SeedPolicy.overwrite?(:workshops)
    end

    with_env("SEED_OVERWRITE_CONTENT" => "1", "SEED_WORKSHOPS" => nil) do
      assert SeedPolicy.overwrite?(:workshops)
    end

    with_env("SEED_OVERWRITE_CONTENT" => nil, "SEED_WORKSHOPS" => "overwrite") do
      assert SeedPolicy.overwrite?(:workshops)
    end
  end

  test "translations preserve present locales unless overwriting" do
    current = { "en" => "Edited", "es" => "" }
    seeded = { "en" => "Seeded", "es" => "Semilla" }

    assert_equal(
      { "en" => "Edited", "es" => "Semilla" },
      SeedPolicy.translations(current, seeded, overwrite: false)
    )
    assert_equal seeded, SeedPolicy.translations(current, seeded, overwrite: true)
  end
end
