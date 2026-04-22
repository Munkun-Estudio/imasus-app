require "test_helper"

class ChallengeSeedTest < ActiveSupport::TestCase
  test "seed_from_yaml! loads every entry from the default seed file" do
    Challenge.seed_from_yaml!
    entries = YAML.load_file(Rails.root.join("db", "seeds", "challenges.yml"))

    assert_equal entries.size, Challenge.count
  end

  test "seed_from_yaml! is idempotent when run twice" do
    Challenge.seed_from_yaml!
    initial_count = Challenge.count
    Challenge.seed_from_yaml!

    assert_equal initial_count, Challenge.count
  end

  test "seed covers the full C1–C10 set" do
    Challenge.seed_from_yaml!

    assert_equal 10, Challenge.count
    assert_equal (1..10).map { |n| "C#{n}" }, Challenge.by_code.pluck(:code)
  end

  test "seed covers all four canonical categories" do
    Challenge.seed_from_yaml!

    categories = Challenge.distinct.pluck(:category).sort
    assert_equal %w[business design material system], categories
  end

  test "English question and description are present for every seed entry" do
    Challenge.seed_from_yaml!

    Challenge.find_each do |challenge|
      assert challenge.question_in(:en).present?,
             "expected '#{challenge.code}' to have an English question"
      assert challenge.description_in(:en).present?,
             "expected '#{challenge.code}' to have an English description"
    end
  end

  test "seed_from_yaml! applies translations to known challenges" do
    Challenge.seed_from_yaml!
    c1 = Challenge.find_by(code: "C1")

    assert_not_nil c1
    assert c1.question_in(:en).present?
    # Stub locales exist in the seed to exercise the pipeline, even if the copy
    # is placeholder.
    assert_not_nil c1.question_in(:es)
  end
end
