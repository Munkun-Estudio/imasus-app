# Holds parsed metadata and body for a single training module section
# (e.g. zero-waste-design / training-module / en).
#
# Constructed by {TrainingModule::Loader} from a markdown file's YAML
# frontmatter and body content. Not an ActiveRecord model.
#
# @attr_reader title [String] display title from frontmatter
# @attr_reader module_slug [String] parent module slug
# @attr_reader module_title [String] parent module display title
# @attr_reader locale [String] ISO 639-1 locale code
# @attr_reader volume [String] section type ("training-module", "case-study", "toolkit")
# @attr_reader available_modules [Array<String>] slugs of all modules in the programme
# @attr_reader available_locales [Array<String>] locales this content is translated into
# @attr_reader available_sections [Array<String>] sections available for this module
# @attr_reader body [String] raw markdown body (without frontmatter)
class TrainingModule::Section
  attr_reader :title, :module_slug, :module_title, :locale, :volume,
              :available_modules, :available_locales, :available_sections, :body

  # @param frontmatter [Hash] parsed YAML frontmatter
  # @param body [String] raw markdown body
  def initialize(frontmatter:, body:)
    @title = frontmatter["title"]
    @module_slug = frontmatter["module_slug"]
    @module_title = frontmatter["module_title"]
    @locale = frontmatter["lang"]
    @volume = frontmatter["volume"]
    @available_modules = Array(frontmatter["available_modules"])
    @available_locales = Array(frontmatter["available_languages"])
    @available_sections = Array(frontmatter["available_volumes"])
    @body = body
  end
end
