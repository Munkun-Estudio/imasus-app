# Namespace for training module POROs.
# Training modules are static markdown content read from the filesystem,
# not ActiveRecord models.
module TrainingModule
  CONTENT_PATH = Rails.root.join("content", "training-modules")
end
