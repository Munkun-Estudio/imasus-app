# View helper for wrapping glossary-term occurrences in rendered HTML with
# Stimulus-bound popover triggers.
#
# Intended for use on content surfaces that may reference workshop vocabulary:
# training module bodies, material descriptions, and workshop help / guidance
# texts. Wrap the output of your sanitize call:
#
#   <%= glossary_highlight sanitize(@rendered_body, ...) %>
#
# The helper loads every glossary term once per request (memoised on the view
# instance) so multiple calls on the same page do not re-query.
module GlossaryHighlightHelper
  # Applies {GlossaryHighlighter} to an HTML fragment and marks the result
  # html-safe so it can be output directly by ERB.
  #
  # @param html [String, ActiveSupport::SafeBuffer, nil]
  # @return [ActiveSupport::SafeBuffer] highlighted HTML, or the input itself
  #   when the input is blank.
  def glossary_highlight(html)
    return html if html.blank?

    highlighted = GlossaryHighlighter.new(html.to_s, terms: glossary_highlight_terms).call
    highlighted.html_safe
  end

  private

  def glossary_highlight_terms
    @glossary_highlight_terms ||= GlossaryTerm.all.to_a
  end
end
