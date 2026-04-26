require "test_helper"

class BookmarkTest < ActiveSupport::TestCase
  setup do
    @password = "correcthorsebatterystaple"
    @user = User.create!(name: "Bookmarker", email: "bookmark-model@example.com",
                         password: @password, role: :participant)
  end

  def valid_attrs(overrides = {})
    {
      user:              @user,
      bookmarkable_type: "Material",
      resource_key:      "42",
      label:             "Kapok Fiber",
      url:               "/materials/kapok"
    }.merge(overrides)
  end

  test "valid with all required attributes" do
    assert Bookmark.new(valid_attrs).valid?
  end

  test "requires user" do
    record = Bookmark.new(valid_attrs(user: nil))
    assert_not record.valid?
    assert record.errors[:user].any?
  end

  test "requires bookmarkable_type" do
    record = Bookmark.new(valid_attrs(bookmarkable_type: nil))
    assert_not record.valid?
    assert record.errors[:bookmarkable_type].any?
  end

  test "requires resource_key" do
    record = Bookmark.new(valid_attrs(resource_key: nil))
    assert_not record.valid?
    assert record.errors[:resource_key].any?
  end

  test "requires label" do
    record = Bookmark.new(valid_attrs(label: nil))
    assert_not record.valid?
    assert record.errors[:label].any?
  end

  test "requires url" do
    record = Bookmark.new(valid_attrs(url: nil))
    assert_not record.valid?
    assert record.errors[:url].any?
  end

  test "enforces uniqueness on [user, bookmarkable_type, resource_key]" do
    Bookmark.create!(valid_attrs)
    dup = Bookmark.new(valid_attrs(label: "Another label"))
    assert_not dup.valid?
    assert dup.errors[:resource_key].any?
  end

  test "allows same resource_key for different users" do
    other = User.create!(name: "Other", email: "other-bm@example.com",
                         password: @password, role: :participant)
    Bookmark.create!(valid_attrs)
    assert Bookmark.new(valid_attrs(user: other)).valid?
  end

  test "allows same resource_key for different bookmarkable_types" do
    Bookmark.create!(valid_attrs)
    other_type = Bookmark.new(valid_attrs(bookmarkable_type: "GlossaryTerm"))
    assert other_type.valid?
  end

  test "user has_many bookmarks" do
    Bookmark.create!(valid_attrs)
    assert_equal 1, @user.bookmarks.count
  end

  test "destroying the user destroys their bookmarks" do
    Bookmark.create!(valid_attrs)
    assert_difference "Bookmark.count", -1 do
      @user.destroy
    end
  end
end
