class Workshop < ApplicationRecord
  include Translatable

  SEED_PATH = Rails.root.join("db", "seeds", "workshops.yml")
  AGENDA_LOCALES = %w[en es it el].freeze
  COMMUNICATION_LOCALES = %w[es it el en].freeze
  SLUG_FALLBACK_LOCALES = %w[en es it el].freeze
  SLUG_MAX_LENGTH = 100

  translates :title, :description

  has_many :participations, class_name: "WorkshopParticipation", dependent: :destroy
  has_many :participants,   through: :participations, source: :user

  has_many :projects, dependent: :destroy
  has_rich_text :agenda_en
  has_rich_text :agenda_es
  has_rich_text :agenda_it
  has_rich_text :agenda_el

  validates :slug,     presence: true, uniqueness: { case_sensitive: false }
  validates :location, presence: true
  validates :starts_on, :ends_on, presence: true
  validates :contact_email,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            allow_blank: true

  before_validation :assign_slug, if: -> { slug.blank? }

  validate :translated_title_present
  validate :translated_description_present
  validate :ends_on_not_before_starts_on

  scope :ordered, -> { order(:starts_on, :location) }
  scope :ready_for_listing, lambda {
    where.not(starts_on: nil, ends_on: nil)
      .where.not(title_translations: {})
      .where.not(description_translations: {})
      .order(:starts_on, :location)
  }

  # @return [String] the stable URL slug for this workshop
  def to_param
    slug
  end

  # Locale-aware title with a final fallback to the first non-blank stored
  # translation so locale-sparse workshop content still renders.
  #
  # @return [String, nil]
  def title
    translated_with_any_locale_fallback(:title_translations)
  end

  # Locale-aware description with a final fallback to the first non-blank
  # stored translation.
  #
  # @return [String, nil]
  def description
    translated_with_any_locale_fallback(:description_translations)
  end

  # @return [Boolean] true when +user+ may create a new workshop. Admin
  #   or any facilitator-role user qualifies — facilitators don't need
  #   a prior {WorkshopParticipation}; the create action auto-attaches
  #   them on save.
  def self.creatable_by?(user)
    return false if user.nil?

    user.admin? || user.facilitator?
  end

  # @return [Boolean] true when +user+ may edit or moderate this workshop.
  #   Admins always; facilitators only when they have a
  #   {WorkshopParticipation} on this workshop. Used as the authorisation
  #   gate for spec-13 surfaces (workshop edit, participants list, project
  #   moderation).
  def manageable_by?(user)
    return false if user.nil?
    return true  if user.admin?

    user.facilitator? && participants.include?(user)
  end

  # Returns the locale-appropriate agenda rich text, falling back through the
  # current locale chain and then to the first non-blank agenda present on the
  # record.
  #
  # @param locale [String, Symbol] requested locale
  # @return [ActionText::RichText, nil]
  def agenda_for(locale = I18n.locale)
    agenda_locale_chain(locale).each do |candidate|
      rich_text = public_send(:"agenda_#{candidate}")
      return rich_text if rich_text.body&.to_plain_text.to_s.strip.present?
    end

    AGENDA_LOCALES.each do |candidate|
      rich_text = public_send(:"agenda_#{candidate}")
      return rich_text if rich_text.body&.to_plain_text.to_s.strip.present?
    end

    nil
  end

  # Returns the best-fit locale for workshop-facing communication such as
  # invitation emails and token-entry pages. Prefer the project's local
  # languages over English when workshop content exists in that locale.
  #
  # @return [String]
  def communication_locale
    COMMUNICATION_LOCALES.find { |locale| content_present_for_locale?(locale) } || I18n.default_locale.to_s
  end

  # Idempotently loads workshops from {SEED_PATH}.
  #
  # @return [void]
  def self.seed_from_yaml!
    payload = YAML.safe_load_file(SEED_PATH, permitted_classes: [ Date ], aliases: true).fetch("workshops")
    seeded_slugs = payload.map { |entry| entry.fetch("slug") }

    payload.each do |entry|
      workshop = find_or_initialize_by(slug: entry.fetch("slug"))
      workshop.assign_attributes(
        title_translations: entry.fetch("title_translations", {}),
        description_translations: entry.fetch("description_translations", {}),
        location: entry.fetch("location"),
        starts_on: entry.fetch("starts_on"),
        ends_on: entry.fetch("ends_on"),
        contact_email: entry["contact_email"]
      )
      workshop.save!

      AGENDA_LOCALES.each do |locale|
        html = entry.fetch("agenda_translations", {})[locale]
        next if html.blank?

        workshop.public_send(:"agenda_#{locale}=", html)
      end
      workshop.save!
    end

    where.not(slug: seeded_slugs)
         .left_outer_joins(:participations)
         .where(workshop_participations: { id: nil })
         .destroy_all
  end

  private

  def agenda_locale_chain(locale)
    locales = [ locale.to_s ]
    if I18n.respond_to?(:fallbacks)
      locales.concat(Array(I18n.fallbacks[locale]).map(&:to_s))
    end
    locales << I18n.default_locale.to_s
    locales.select { |candidate| AGENDA_LOCALES.include?(candidate) }.uniq
  end

  # Auto-generates the slug from the first non-blank title in the
  # `en → es → it → el` fallback order. `parameterize` + max-100-char
  # cap, with `-2`/`-3` collision suffix. Called via
  # `before_validation` only when slug is blank.
  def assign_slug
    base_title = SLUG_FALLBACK_LOCALES.lazy.map { |loc| title_translations[loc].presence }.find(&:itself)
    return if base_title.blank?

    base = base_title.parameterize.first(SLUG_MAX_LENGTH)
    self.slug = unique_slug(base)
  end

  def unique_slug(base)
    candidate = base
    suffix = 2
    while Workshop.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base.first(SLUG_MAX_LENGTH - "-#{suffix}".length)}-#{suffix}"
      suffix += 1
    end
    candidate
  end

  def translated_title_present
    return if title_translations.values.any?(&:present?)

    errors.add(:title_translations, :blank)
  end

  def translated_description_present
    return if description_translations.values.any?(&:present?)

    errors.add(:description_translations, :blank)
  end

  def ends_on_not_before_starts_on
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "must be on or after the start date")
  end

  def translated_with_any_locale_fallback(column)
    translations = public_send(column) || {}
    locales = [ I18n.locale ]
    if I18n.respond_to?(:fallbacks)
      locales.concat(Array(I18n.fallbacks[I18n.locale]))
    end
    locales << I18n.default_locale

    locales.uniq.each do |locale|
      value = translations[locale.to_s].presence
      return value if value.present?
    end

    translations.values.find(&:present?)
  end

  def content_present_for_locale?(locale)
    title_translations[locale].present? ||
      description_translations[locale].present? ||
      public_send(:"agenda_#{locale}").body&.to_plain_text.to_s.strip.present?
  end
end
