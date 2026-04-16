require "test_helper"

class TrainingModule::RendererTest < ActiveSupport::TestCase
  test "renders markdown headings to HTML" do
    html = TrainingModule::Renderer.call("# Hello\n\nWorld")
    assert_includes html, "<h1"
    assert_includes html, "Hello"
    assert_includes html, "<p"
  end

  test "rewrites image src paths from assets to content" do
    markdown = '<img src="/assets/training-modules/media/zero-waste-design/en/training-module/media/image1.png" />'
    html = TrainingModule::Renderer.call(markdown)
    assert_includes html, 'src="/content/training-modules/media/zero-waste-design/en/training-module/media/image1.png"'
    assert_not_includes html, "/assets/training-modules"
  end

  test "strips inline style attributes from img tags" do
    markdown = '<img src="/assets/training-modules/media/test.png" style="width:5.16816in;height:3.54601in" alt="test" />'
    html = TrainingModule::Renderer.call(markdown)
    assert_not_includes html, "style="
    assert_not_includes html, "5.16816in"
  end

  test "adds loading lazy to img tags" do
    markdown = '<img src="/assets/training-modules/media/test.png" alt="test" />'
    html = TrainingModule::Renderer.call(markdown)
    assert_includes html, 'loading="lazy"'
  end

  test "preserves alt attributes on img tags" do
    markdown = '<img src="/assets/training-modules/media/test.png" alt="A cool image" />'
    html = TrainingModule::Renderer.call(markdown)
    assert_includes html, 'alt="A cool image"'
  end
end
