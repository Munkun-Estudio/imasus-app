require "yaml"

# Enumerates training modules, sections, and locales from the filesystem.
# Returns nil for missing content — callers handle 404s.
#
# Training modules are static markdown files with YAML frontmatter, read from
# +content/training-modules/+ at the project root.
#
# @example List all modules
#   loader = TrainingModule::Loader.new
#   loader.all # => [#<TrainingModule::ModuleInfo slug="design-for-longevity" ...>, ...]
#
# @example Load a specific section
#   loader.section("zero-waste-design", "training-module", "en")
#   # => #<TrainingModule::Section title="Zero Waste Design" ...>
class TrainingModule::Loader
  MODULES_DIR = TrainingModule::CONTENT_PATH
  MODULE_SLUGS = %w[design-for-longevity design-for-modularity design-for-recyclability zero-waste-design].freeze

  # Returns all available modules as ModuleInfo objects.
  #
  # @return [Array<TrainingModule::ModuleInfo>]
  def all
    MODULE_SLUGS.filter_map { |slug| build_module_info(slug) }
  end

  # Finds a single module by slug.
  #
  # @param slug [String] the module slug (e.g. "zero-waste-design")
  # @return [TrainingModule::ModuleInfo, nil] nil if the slug is unknown
  def find(slug)
    return nil unless MODULE_SLUGS.include?(slug)
    build_module_info(slug)
  end

  # Loads a specific section for a module/section/locale combination.
  #
  # @param slug [String] module slug
  # @param volume [String] section type ("training-module", "case-study", "toolkit")
  # @param locale [String] ISO 639-1 locale code
  # @return [TrainingModule::Section, nil] nil if the file does not exist
  def section(slug, volume, locale)
    path = MODULES_DIR.join(slug, locale, "#{volume}.md")
    return nil unless path.exist?
    parse_file(path)
  end

  # Loads the "about training" page for a given locale.
  #
  # @param locale [String] ISO 639-1 locale code
  # @return [TrainingModule::Section, nil] nil if the file does not exist
  def about(locale)
    path = MODULES_DIR.join(locale, "about.md")
    return nil unless path.exist?
    parse_file(path)
  end

  private

  def build_module_info(slug)
    # Read metadata from the English training-module file as the canonical source
    section = section(slug, "training-module", "en")
    return nil unless section

    TrainingModule::ModuleInfo.new(
      slug: slug,
      title: section.module_title || section.title,
      available_locales: section.available_locales,
      available_sections: section.available_sections
    )
  end

  def parse_file(path)
    content = path.read
    frontmatter, body = split_frontmatter(content)
    TrainingModule::Section.new(frontmatter: frontmatter, body: body)
  end

  def split_frontmatter(content)
    if content.start_with?("---")
      parts = content.split("---", 3)
      frontmatter = YAML.safe_load(parts[1], permitted_classes: []) || {}
      body = parts[2].to_s.strip
    else
      frontmatter = {}
      body = content.strip
    end
    [ frontmatter, body ]
  end
end
