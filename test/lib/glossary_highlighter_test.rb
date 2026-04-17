require "test_helper"

class GlossaryHighlighterTest < ActiveSupport::TestCase
  setup do
    @framework = GlossaryTerm.create!(
      slug:     "framework",
      category: "methodology",
      term_translations:       { "en" => "Framework" },
      definition_translations: { "en" => "A shared structure of concepts." }
    )
    @imagineering = GlossaryTerm.create!(
      slug:     "imagineering",
      category: "methodology",
      term_translations:       { "en" => "Imagineering" },
      definition_translations: { "en" => "A complexity-informed design discipline." }
    )
    @creative_tension = GlossaryTerm.create!(
      slug:     "creative-tension-engine",
      category: "methodology",
      term_translations:       { "en" => "Creative Tension Engine" },
      definition_translations: { "en" => "A shared generative vision." }
    )
  end

  def highlight(html)
    GlossaryHighlighter.new(html, terms: GlossaryTerm.all).call
  end

  test "wraps a known term with the popover controller markup" do
    out = highlight("<p>This is a framework.</p>")

    assert_includes out, "data-controller=\"glossary-popover\""
    assert_includes out, "data-glossary-popover-slug-value=\"framework\""
  end

  test "matching is case-insensitive and preserves the original casing" do
    out = highlight("<p>FRAMEWORK matters here.</p>")

    assert_includes out, ">FRAMEWORK<"
    assert_includes out, "data-glossary-popover-slug-value=\"framework\""
  end

  test "wraps only the first occurrence of a term on the page" do
    out = highlight("<p>framework. framework. framework.</p>")

    assert_equal 1, out.scan("data-glossary-popover-slug-value=\"framework\"").size
  end

  test "does not wrap matches inside <code> blocks" do
    out = highlight("<p>Use <code>framework</code> as a literal.</p>")

    refute_includes out, "data-glossary-popover-slug-value=\"framework\""
  end

  test "does not wrap matches inside <pre> blocks" do
    out = highlight("<pre>framework()</pre>")

    refute_includes out, "data-glossary-popover-slug-value=\"framework\""
  end

  test "does not wrap matches inside existing <a> anchors" do
    out = highlight(%(<p>Read <a href="/other">framework here</a> today.</p>))

    refute_includes out, "data-glossary-popover-slug-value=\"framework\""
  end

  test "does not match partial words inside other words" do
    out = highlight("<p>frameworkless software</p>")

    refute_includes out, "data-glossary-popover-slug-value=\"framework\""
  end

  test "matches multi-word terms as a whole unit" do
    out = highlight("<p>The Creative Tension Engine reframes the challenge.</p>")

    assert_includes out, "data-glossary-popover-slug-value=\"creative-tension-engine\""
    assert_includes out, ">Creative Tension Engine<"
  end

  test "matches longer terms preferentially when they overlap shorter ones" do
    extra = GlossaryTerm.create!(
      slug:     "engine",
      category: "methodology",
      term_translations:       { "en" => "Engine" },
      definition_translations: { "en" => "A motor." }
    )

    out = GlossaryHighlighter.new(
      "<p>The Creative Tension Engine reframes.</p>",
      terms: GlossaryTerm.all
    ).call

    assert_includes out, "data-glossary-popover-slug-value=\"creative-tension-engine\""
    refute_includes out, "data-glossary-popover-slug-value=\"engine\""
  end

  test "handles multiple distinct terms in the same HTML" do
    out = highlight("<p>A framework informed by imagineering.</p>")

    assert_includes out, "data-glossary-popover-slug-value=\"framework\""
    assert_includes out, "data-glossary-popover-slug-value=\"imagineering\""
  end

  test "returns the input unchanged when the terms list is empty" do
    html = "<p>No glossary terms available.</p>"
    out  = GlossaryHighlighter.new(html, terms: []).call

    assert_equal html.strip, out.strip
  end

  test "empty/blank HTML is returned as-is" do
    assert_equal "", GlossaryHighlighter.new("", terms: GlossaryTerm.all).call
    assert_equal "   ", GlossaryHighlighter.new("   ", terms: GlossaryTerm.all).call
  end
end
