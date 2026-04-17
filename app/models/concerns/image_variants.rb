module ImageVariants
  extend ActiveSupport::Concern

  PRESETS = {
    thumbnail: {
      resize_to_limit: [ 200, 200 ],
      width: 200,
      height: 200
    },
    card: {
      resize_to_limit: [ 400, 300 ],
      width: 400,
      height: 300
    },
    detail: {
      resize_to_limit: [ 1200, 1200 ],
      width: 1200,
      height: 1200
    },
    hero: {
      resize_to_limit: [ 1600, 900 ],
      width: 1600,
      height: 900
    }
  }.freeze

  class_methods do
    # @return [Hash] the shared preset definitions for attached images
    def image_variant_definitions
      PRESETS
    end
  end

  class << self
    # @param preset [String, Symbol] preset name such as :card or :hero
    # @return [Hash] Active Storage transformation options
    def transformations(preset)
      definition = fetch(preset)

      { resize_to_limit: definition.fetch(:resize_to_limit) }
    end

    # @param preset [String, Symbol] preset name
    # @return [Hash] width and height metadata used for layout stability
    def dimensions(preset)
      definition = fetch(preset)

      {
        width: definition.fetch(:width),
        height: definition.fetch(:height)
      }
    end

    # @param attachable [ActiveStorage::Attached, ActiveStorage::Blob] uploaded image
    # @param preset [String, Symbol] preset name
    # @return [ActiveStorage::Variant, ActiveStorage::VariantWithRecord] image variant
    def variant_for(attachable, preset)
      attachable.variant(transformations(preset))
    end

    private

    def fetch(preset)
      PRESETS.fetch(preset.to_sym)
    rescue KeyError
      raise ArgumentError, "Unknown image variant: #{preset}"
    end
  end
end
