require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "sanitized_email_html strips unsafe tags and handlers" do
    html = <<~HTML
      <div><strong>Hello</strong><script>alert("x")</script>
      <img src="https://example.com/a.png" onerror="alert('x')"></div>
    HTML

    sanitized = sanitized_email_html(html)

    assert_includes sanitized, "<strong>Hello</strong>"
    assert_includes sanitized, %(<img src="https://example.com/a.png">)
    assert_not_includes sanitized, "<script>"
    assert_not_includes sanitized, "onerror"
  end
end
