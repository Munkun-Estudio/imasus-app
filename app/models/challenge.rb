# One of the ten framing challenges (C1–C10) that a participant picks when
# scoping project work during an IMASUS workshop.
#
# Each challenge carries translations for `question` and `description` via the
# {Translatable} concern, plus a stable `code` (e.g. "C1") and a `category`
# (one of {CATEGORIES}). The code is the URL-facing identifier — rendered in
# lowercase via {#to_param} — and is compared case-insensitively for
# uniqueness.
#
# The set is fixed at ten: curators may edit copy, but there is no `new` or
# `destroy` action. See `.munkit/specs/2026-04-22-challenge-cards/brief.md`.
class Challenge < ApplicationRecord
  include Translatable

  # Fixed list of category values. A fifth value would be a one-line change
  # here plus a colour-mapping update in the `ChallengeCard` partial.
  CATEGORIES = %w[material design system business].freeze

  # Canonical code format: "C" followed by 1–10.
  CODE_FORMAT = /\AC([1-9]|10)\z/

  # Source-of-truth locale for presence validation.
  BASE_LOCALE = "en"

  # Default seed file path. Override via the `path:` argument to {.seed_from_yaml!}.
  SEED_PATH = Rails.root.join("db", "seeds", "challenges.yml")

  translates :question, :description

  before_validation :normalize_code

  validates :code, presence: true, format: { with: CODE_FORMAT }
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  validate :unique_code_case_insensitive
  validate :base_locale_question_present
  validate :base_locale_description_present

  # Numeric ordering so `C2` sorts before `C10`. Applied explicitly by callers
  # rather than as a default scope, which would break `distinct` / `pluck`
  # combinations under PostgreSQL.
  scope :by_code, -> { order(Arel.sql("(substring(code from 2))::int")) }

  # @return [String] the code lowercased for URL generation
  def to_param
    code&.downcase
  end

  # Idempotent loader that upserts every entry in the seed YAML. Each entry is
  # matched by `code`, so re-running updates the question, description, and
  # category without duplicating rows.
  #
  # @param path [Pathname, String] seed file path (tests override this)
  # @return [Integer] the number of challenges after loading
  # @raise [ActiveRecord::RecordInvalid] if any entry fails validation
  def self.seed_from_yaml!(path: SEED_PATH)
    entries = YAML.load_file(path)

    entries.each do |entry|
      challenge = find_or_initialize_by(code: entry.fetch("code"))
      challenge.category                 = entry.fetch("category")
      challenge.question_translations    = entry.fetch("question")
      challenge.description_translations = entry.fetch("description")
      challenge.save!
    end

    count
  end

  private

  def normalize_code
    self.code = code.upcase if code.is_a?(String)
  end

  def unique_code_case_insensitive
    return if code.blank?

    scope = Challenge.unscoped.where("UPPER(code) = ?", code.upcase)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:code, :taken) if scope.exists?
  end

  def base_locale_question_present
    return if base_locale_value(question_translations).present?

    errors.add(:question_translations, :blank)
  end

  def base_locale_description_present
    return if base_locale_value(description_translations).present?

    errors.add(:description_translations, :blank)
  end

  def base_locale_value(translations)
    (translations || {})[BASE_LOCALE].to_s.strip
  end
end
