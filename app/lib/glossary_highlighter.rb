require "nokogiri"
require "set"

# Wraps glossary-term occurrences inside an HTML fragment with Stimulus-bound
# trigger buttons, so the {GlossaryPopoverController} on the frontend can
# reveal the definition on click.
#
# ## Matching strategy
#
# * **Case-insensitive** against the term's text in the target locale
#   (falling back to the base locale), preserving the original casing in the
#   output.
# * **First occurrence per term, per call.** Later occurrences of the same
#   term on the same page are left as plain text — glossary popovers are a
#   reading aid, and one trigger per concept is enough to avoid visual noise
#   in longer passages.
# * **Longest match wins** when terms overlap (e.g. "Creative Tension Engine"
#   is preferred over a standalone "Engine" term appearing inside it).
# * **Word-boundary** matches only — "frameworkless" does not trigger the
#   "framework" term.
#
# ## Skipped regions
#
# Matches are ignored inside `<a>`, `<code>`, and `<pre>` ancestors so the
# highlighter does not hijack existing links or code samples.
#
# @example
#   html = "<p>A framework for imagineering.</p>"
#   GlossaryHighlighter.new(html, terms: GlossaryTerm.all).call
#   # => "<p>A <button type=\"button\" ...>framework</button> for
#   #     <button type=\"button\" ...>imagineering</button>.</p>"
class GlossaryHighlighter
  # HTML tags whose descendants are excluded from matching.
  SKIP_ANCESTORS = %w[a code pre].freeze

  # @param html [String] the HTML fragment to process (may contain multiple
  #   sibling nodes).
  # @param terms [Enumerable<GlossaryTerm>] the glossary terms to match.
  # @param first_occurrence_only [Boolean] when true (default), wraps only the
  #   first occurrence of each term in this call.
  # @param locale [String, Symbol, nil] the locale whose term text is matched.
  #   Defaults to `I18n.locale`. Falls back to {GlossaryTerm::BASE_LOCALE}
  #   when the per-locale term is blank.
  def initialize(html, terms:, first_occurrence_only: true, locale: nil)
    @html = html.to_s
    @terms = terms
    @first_occurrence_only = first_occurrence_only
    @locale = (locale || I18n.locale).to_s
  end

  # Runs the highlighter and returns the modified HTML.
  #
  # @return [String] HTML with matched terms wrapped as popover triggers. The
  #   input is returned unchanged when empty, when no terms are supplied, or
  #   when no terms have matchable text.
  def call
    return @html if @html.strip.empty?

    lookup = build_lookup
    return @html if lookup.empty?

    regex    = build_regex(lookup.keys)
    fragment = Nokogiri::HTML5.fragment(@html)
    matched  = Set.new

    fragment.xpath(text_node_xpath).each do |node|
      replaced = node.content.gsub(regex) do |match|
        slug = lookup[match.downcase]
        next match if @first_occurrence_only && matched.include?(slug)

        matched << slug
        wrap(match, slug)
      end

      node.replace(Nokogiri::HTML5.fragment(replaced)) if replaced != node.content
    end

    fragment.to_html
  end

  private

  def build_lookup
    @terms.each_with_object({}) do |term, acc|
      text = term.term_in(@locale).presence || term.term_in(GlossaryTerm::BASE_LOCALE)
      next if text.blank?

      acc[text.downcase] ||= term.slug
    end
  end

  def build_regex(keys)
    sorted = keys.sort_by { |k| -k.length }
    alternation = sorted.map { |k| Regexp.escape(k) }.join("|")
    Regexp.new("\\b(#{alternation})\\b", Regexp::IGNORECASE)
  end

  def text_node_xpath
    skips = SKIP_ANCESTORS.map { |tag| "not(ancestor::#{tag})" }.join(" and ")
    ".//text()[#{skips}]"
  end

  def wrap(match, slug)
    %(<button type="button" class="glossary-term" ) +
      %(data-controller="glossary-popover" ) +
      %(data-glossary-popover-slug-value="#{slug}">) +
      ERB::Util.html_escape(match) +
      "</button>"
  end
end
