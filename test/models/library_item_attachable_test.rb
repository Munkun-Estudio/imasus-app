require "test_helper"

class LibraryItemAttachableTest < ActiveSupport::TestCase
  test "Action Text references resolve and render the current generic item" do
    LibraryItem.seed_from_manifest!(overwrite: true)
    item = LibraryItem.find_by!(slug: "pyratex-musa-1")
    content = ActionText::Content.new(
      %(<action-text-attachment sgid="#{item.attachable_sgid}"></action-text-attachment>)
    )

    assert_equal [ item ], content.attachables
    rendered = content.to_rendered_html_with_layout
    assert_includes rendered, item.title
    assert_includes rendered, "/library/#{item.slug}"
  end

  test "retired references keep resolving through their stable signed identity" do
    LibraryItem.seed_from_manifest!(overwrite: true)
    item = LibraryItem.find_by!(slug: "pyratex-musa-1")
    sgid = item.attachable_sgid
    item.update_columns(published: false)

    assert_equal item, LibraryItem.from_attachable_sgid(sgid)
    rendered = ActionText::Content.new(
      %(<action-text-attachment sgid="#{sgid}"></action-text-attachment>)
    ).to_rendered_html_with_layout
    assert_includes rendered, I18n.t("library_items.reference.retired")
  end
end
