# Keep the IMASUS presentation model available while the underlying Library is
# generic. Explicit loading makes adapter registration independent of autoload
# order in seeds, tasks, tests, and eager-loaded production.
Rails.application.config.to_prepare do
  LibraryItem.register_adapter("material", Material)
  Tag::FACETS.each { |facet| LibraryTaxonomyTerm.register_adapter(facet, Tag) }
end
