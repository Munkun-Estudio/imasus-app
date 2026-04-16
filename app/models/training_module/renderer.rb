require "kramdown"

# Converts training module markdown to HTML with image post-processing.
#
# Handles raw +<img>+ tags from DOCX-converted content by:
# - Rewriting +src+ paths from +/assets/+ to +/content/+
# - Stripping inline +style+ attributes (inch-based widths)
# - Adding +loading="lazy"+ for performance
#
# @example
#   TrainingModule::Renderer.call("# Hello\n\nWorld")
#   # => "<h1 id=\"hello\">Hello</h1>\n<p>World</p>\n"
class TrainingModule::Renderer
  # Renders markdown content to HTML with image post-processing.
  #
  # @param markdown [String] raw markdown content (may include HTML img tags)
  # @return [String] rendered HTML
  def self.call(markdown)
    html = Kramdown::Document.new(markdown, input: "kramdown", html_to_native: false).to_html
    process_images(html)
  end

  def self.process_images(html)
    html.gsub(/<img\s[^>]*>/i) do |tag|
      tag = rewrite_src(tag)
      tag = strip_style(tag)
      tag = add_lazy_loading(tag)
      tag
    end
  end
  private_class_method :process_images

  def self.rewrite_src(tag)
    tag.gsub(%r{src="/assets/training-modules/}, 'src="/content/training-modules/')
  end
  private_class_method :rewrite_src

  def self.strip_style(tag)
    tag.gsub(/\s*style="[^"]*"/, "")
  end
  private_class_method :strip_style

  def self.add_lazy_loading(tag)
    return tag if tag.include?("loading=")
    tag.sub(/<img/, '<img loading="lazy"')
  end
  private_class_method :add_lazy_loading
end
