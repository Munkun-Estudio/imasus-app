module ImageVariantsHelper
  # Renders a shared image variant with lazy loading and explicit dimensions
  # so future views avoid layout shift by default.
  #
  # @param attachable [ActiveStorage::Attached, ActiveStorage::Blob] uploaded image
  # @param preset [String, Symbol] preset name
  # @param alt [String] accessible alternate text
  # @param options [Hash] extra options passed to image_tag
  # @return [String] rendered image tag
  def image_variant_tag(attachable, preset:, alt:, **options)
    dimensions = ImageVariants.dimensions(preset)

    image_tag(
      ImageVariants.variant_for(attachable, preset).processed,
      {
        alt: alt,
        loading: "lazy",
        width: dimensions.fetch(:width),
        height: dimensions.fetch(:height)
      }.merge(options)
    )
  end
end
