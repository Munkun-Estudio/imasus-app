# Namespace for training module POROs.
# Training modules are static markdown content read from the filesystem,
# not ActiveRecord models.
module TrainingModule
  MANIFEST_FILENAME = "manifest.yml"

  def self.content_path
    Rails.configuration.site.content.guides
  end
end
