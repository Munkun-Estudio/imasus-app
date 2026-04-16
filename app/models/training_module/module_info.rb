# Lightweight value object representing a training module's metadata
# (slug, title, available locales/sections) without loading full content.
#
# Returned by {TrainingModule::Loader#all} and {TrainingModule::Loader#find}.
#
# @attr_reader slug [String] URL-friendly module identifier
# @attr_reader title [String] display title
# @attr_reader available_locales [Array<String>] ISO 639-1 locale codes
# @attr_reader available_sections [Array<String>] section types
class TrainingModule::ModuleInfo
  attr_reader :slug, :title, :available_locales, :available_sections

  # @param slug [String]
  # @param title [String]
  # @param available_locales [Array<String>]
  # @param available_sections [Array<String>]
  def initialize(slug:, title:, available_locales:, available_sections:)
    @slug = slug
    @title = title
    @available_locales = available_locales
    @available_sections = available_sections
  end
end
