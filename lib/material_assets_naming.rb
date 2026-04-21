module MaterialAssetsNaming
  VIDEO_EXTENSIONS = %w[.mp4 .mov .webm].freeze
  MICROSCOPY_SUFFIX = /-m(?<n>\d+)\z/i

  module_function

  def classify(file, image_extensions:)
    path = Pathname(file)
    ext = path.extname.downcase
    stem = path.basename(path.extname).to_s

    if image_extensions.include?(ext) && (match = stem.match(MICROSCOPY_SUFFIX))
      index = match[:n].to_i
      return [ nil, nil ] if index <= 0

      [ :microscopy, index - 1 ]
    elsif image_extensions.include?(ext)
      [ :macro, 0 ]
    elsif VIDEO_EXTENSIONS.include?(ext)
      [ :video, 0 ]
    else
      [ nil, nil ]
    end
  end
end
