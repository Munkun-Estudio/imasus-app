module LibraryCatalog
  def self.current
    @current ||= Manifest.load(path: Rails.configuration.site.content.library)
  end

  def self.reset!
    @current = nil
  end
end
