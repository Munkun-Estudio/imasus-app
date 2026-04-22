# Concern for models with per-locale textual attributes backed by JSONB columns.
#
# Each translatable attribute is stored in a sibling column named
# `<attribute>_translations` as a JSON object keyed by locale code. The concern
# defines three accessor methods per attribute:
#
#   * `<attr>`              — reads the value for `I18n.locale`, then any
#                             configured I18n fallbacks, then the default
#                             locale when the current locale chain is blank.
#                             Returns `nil` when that chain is blank.
#   * `<attr>=`             — writes the value into the slot for `I18n.locale`,
#                             preserving the other locales.
#   * `<attr>_in(locale)`   — reads the exact locale slot with no fallback.
#                             Useful for locale-tab form editors.
#
# @example
#   class GlossaryTerm < ApplicationRecord
#     include Translatable
#     translates :term, :definition, :examples
#   end
#
#   term = GlossaryTerm.new(term_translations: { "en" => "Framework", "es" => "Marco" })
#   I18n.with_locale(:es) { term.term }        # => "Marco"
#   I18n.with_locale(:it) { term.term }        # => "Framework" (fallback)
#   term.term_in(:es)                          # => "Marco"
module Translatable
  extend ActiveSupport::Concern

  class_methods do
    # Declares one or more translatable attributes backed by `<attr>_translations`
    # JSONB columns.
    #
    # @param attrs [Array<Symbol>] attribute names (not including `_translations` suffix)
    # @return [void]
    def translates(*attrs)
      attrs.each do |attr|
        column = :"#{attr}_translations"

        define_method(attr) do
          translations = public_send(column) || {}
          locales = [ I18n.locale ]
          if I18n.respond_to?(:fallbacks)
            locales.concat(Array(I18n.fallbacks[I18n.locale]))
          end
          locales << I18n.default_locale

          locales.uniq.each do |locale|
            value = translations[locale.to_s].presence
            return value if value.present?
          end

          nil

        end

        define_method(:"#{attr}=") do |value|
          current = (public_send(column) || {}).dup
          current[I18n.locale.to_s] = value
          public_send(:"#{column}=", current)
        end

        define_method(:"#{attr}_in") do |locale|
          translations = public_send(column) || {}
          translations[locale.to_s]
        end
      end
    end
  end
end
