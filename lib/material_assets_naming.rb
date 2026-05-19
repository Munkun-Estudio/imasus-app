module MaterialAssetsNaming
  VIDEO_EXTENSIONS = %w[.mp4 .mov .webm].freeze
  MICROSCOPY_SUFFIX = /(?:[-_.]?m_?)(?<n>\d+)\z/i

  module_function

  def classify(file, image_extensions:, material_stem: nil)
    path = Pathname(file)
    ext = path.extname.downcase
    stem = path.basename(path.extname).to_s

    if image_extensions.include?(ext) && (match = stem.match(MICROSCOPY_SUFFIX))
      index = match[:n].to_i
      return [ nil, nil ] if index <= 0

      [ :microscopy, index - 1 ]
    elsif image_extensions.include?(ext)
      [ :macro, macro_position_for(stem, material_stem) ]
    elsif VIDEO_EXTENSIONS.include?(ext)
      [ :video, 0 ]
    else
      [ nil, nil ]
    end
  end

  def macro_position_for(stem, material_stem)
    return 0 if material_stem.to_s.strip.empty?

    normalized_stem = normalize(stem)
    normalized_material_stem = normalize(material_stem)
    return 0 if normalized_stem == normalized_material_stem

    suffix = normalized_stem.delete_prefix(normalized_material_stem)
    return 0 unless (match = suffix.match(/\A[-_ ]?(?<n>\d+)\z/))

    [ match[:n].to_i - 1, 0 ].max
  end

  def normalize(value)
    value.to_s.strip.downcase
  end
end
