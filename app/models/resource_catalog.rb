module ResourceCatalog
  def self.prompts
    Manifest.load(
      path: Rails.configuration.site.content.prompts,
      resource: "prompts",
      fields: { "question" => :string, "description" => :string }
    )
  end

  def self.glossary
    Manifest.load(
      path: Rails.configuration.site.content.glossary,
      resource: "glossary",
      fields: { "term" => :string, "definition" => :string, "examples" => :array },
      optional_fields: %w[examples]
    )
  end
end
