require "test_helper"

class ChallengeTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      code:                     "C1",
      category:                 "material",
      question_translations:    { "en" => "How might we reduce textile waste at source?" },
      description_translations: { "en" => "Framing question for material-focused project work." }
    }.merge(overrides)
  end

  # --- Translatable: readers -------------------------------------------------

  test "question reads from the current locale" do
    challenge = Challenge.new(question_translations: { "en" => "English Q", "es" => "Pregunta ES" })
    assert_equal "English Q",   I18n.with_locale(:en) { challenge.question }
    assert_equal "Pregunta ES", I18n.with_locale(:es) { challenge.question }
  end

  test "description falls back to the default (en) locale when current is missing" do
    challenge = Challenge.new(description_translations: { "en" => "Base description" })
    assert_equal "Base description", I18n.with_locale(:it) { challenge.description }
  end

  test "question_in returns the exact locale value without fallback" do
    challenge = Challenge.new(question_translations: { "en" => "Q" })
    assert_equal "Q", challenge.question_in(:en)
    assert_nil        challenge.question_in(:es)
  end

  # --- Validations -----------------------------------------------------------

  test "valid with code, category, and base-locale question and description" do
    assert Challenge.new(valid_attributes).valid?
  end

  test "requires a code" do
    record = Challenge.new(valid_attributes(code: nil))
    assert_not record.valid?
    assert record.errors[:code].any?
  end

  test "accepts C1 through C10 as canonical codes" do
    (1..10).each do |n|
      record = Challenge.new(valid_attributes(code: "C#{n}"))
      assert record.valid?, "expected 'C#{n}' to validate: #{record.errors.full_messages.to_sentence}"
    end
  end

  test "rejects codes outside the C1–C10 range or malformed shape" do
    %w[C0 C11 C99 X1 CC1 1C].each do |bad|
      record = Challenge.new(valid_attributes(code: bad))
      assert_not record.valid?, "expected '#{bad}' to be rejected"
      assert record.errors[:code].any?
    end
  end

  test "normalizes lowercase code input to uppercase on validation" do
    record = Challenge.new(valid_attributes(code: "c1"))
    assert record.valid?, "expected 'c1' to normalize and validate"
    assert_equal "C1", record.code
  end

  test "enforces case-insensitive uniqueness of code" do
    Challenge.create!(valid_attributes)
    dup = Challenge.new(valid_attributes(code: "C1")) # same code
    assert_not dup.valid?
    assert dup.errors[:code].any?
  end

  test "requires a category" do
    record = Challenge.new(valid_attributes(category: nil))
    assert_not record.valid?
    assert record.errors[:category].any?
  end

  test "rejects an unknown category" do
    record = Challenge.new(valid_attributes(category: "unknown"))
    assert_not record.valid?
    assert record.errors[:category].any?
  end

  test "accepts each of the four canonical categories" do
    %w[material design system business].each_with_index do |category, i|
      record = Challenge.new(valid_attributes(category: category, code: "C#{i + 1}"))
      assert record.valid?, "expected '#{category}' to validate: #{record.errors.full_messages.to_sentence}"
    end
  end

  test "requires an English (base-locale) question" do
    record = Challenge.new(valid_attributes(question_translations: { "es" => "ES" }))
    assert_not record.valid?
    assert record.errors[:question_translations].any?
  end

  test "requires an English (base-locale) description" do
    record = Challenge.new(valid_attributes(description_translations: { "es" => "ES" }))
    assert_not record.valid?
    assert record.errors[:description_translations].any?
  end

  # --- Ordering --------------------------------------------------------------

  test "by_code scope orders C2 before C10 (numeric, not lexicographic)" do
    [ "C10", "C2", "C1" ].each do |code|
      Challenge.create!(valid_attributes(code: code))
    end

    assert_equal [ "C1", "C2", "C10" ], Challenge.by_code.pluck(:code)
  end

  # --- URL parameter ---------------------------------------------------------

  test "to_param returns the code lowercased for URL generation" do
    challenge = Challenge.create!(valid_attributes)
    assert_equal "c1", challenge.to_param
  end
end
