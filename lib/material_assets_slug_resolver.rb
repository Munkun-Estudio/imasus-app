# Resolves partner media folder names to canonical Material slugs.
#
# Most folders map directly through `parameterize`; the aliases cover confirmed
# source/database spelling mismatches in the partner Drive export.
module MaterialAssetsSlugResolver
  ALIASES = {
    "pyratex-freshness-4"          => "pyratex-freshness-1",
    "torne-grup-cothepmat-305"     => "torne-grup-cothempmat-305",
    "torne-grup-cotlinmat-236"     => "torne-grup-cottlinmat-236"
  }.freeze

  module_function

  def call(folder_name)
    slug = folder_name.to_s.strip.downcase.parameterize
    ALIASES.fetch(slug, slug)
  end
end
