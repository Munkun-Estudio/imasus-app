# Runtime policy for repository-backed seed loaders.
#
# Production data now includes facilitator/admin edits, so content seeds default
# to a conservative mode: create missing records and fill blank fields, but do
# not overwrite existing content unless an explicit refresh flag is present.
module SeedPolicy
  TRUE_VALUES = %w[1 true yes y overwrite force refresh].freeze

  module_function

  # @param scope [Symbol, String] content area, e.g. :workshops
  # @return [Boolean] whether seed loaders should overwrite existing content
  def overwrite?(scope)
    truthy?(ENV["SEED_OVERWRITE_CONTENT"]) ||
      truthy?(ENV["SEED_#{scope.to_s.upcase}_OVERWRITE"]) ||
      truthy?(ENV["SEED_#{scope.to_s.upcase}_MODE"]) ||
      truthy?(ENV["SEED_#{scope.to_s.upcase}"])
  end

  # @param current [Object] existing value
  # @param seeded [Object] seed value
  # @param overwrite [Boolean]
  # @return [Object]
  def value(current, seeded, overwrite:)
    return seeded if overwrite
    return seeded if current.blank?

    current
  end

  # Merges seed translations into an existing JSONB translation hash without
  # overwriting present locale values unless overwrite mode is enabled.
  #
  # @param current [Hash, nil]
  # @param seeded [Hash, nil]
  # @param overwrite [Boolean]
  # @return [Hash]
  def translations(current, seeded, overwrite:)
    seeded = (seeded || {}).stringify_keys
    return seeded if overwrite

    current = (current || {}).stringify_keys
    seeded.each do |locale, value|
      current[locale] = value if current[locale].blank? && value.present?
    end
    current
  end

  def truthy?(value)
    TRUE_VALUES.include?(value.to_s.downcase)
  end
  private_class_method :truthy?
end
