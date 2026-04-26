require "test_helper"

class BookmarksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @password     = "correcthorsebatterystaple"
    @user         = User.create!(name: "User",  email: "bm-ctrl@example.com",  password: @password, role: :participant)
    @other_user   = User.create!(name: "Other", email: "bm-other@example.com", password: @password, role: :participant)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  def create_params(overrides = {})
    {
      bookmark: {
        bookmarkable_type: "Material",
        resource_key:      "42",
        label:             "Kapok Fiber",
        url:               "/materials/kapok"
      }.merge(overrides)
    }
  end

  # Index

  test "GET /bookmarks redirects unauthenticated user" do
    get bookmarks_url
    assert_redirected_to new_session_path
  end

  test "GET /bookmarks returns 200 for authenticated user" do
    sign_in @user
    get bookmarks_url
    assert_response :success
  end

  test "GET /bookmarks only shows current user bookmarks" do
    sign_in @user
    Bookmark.create!(user: @user,       bookmarkable_type: "Material", resource_key: "1", label: "Mine",  url: "/m/1")
    Bookmark.create!(user: @other_user, bookmarkable_type: "Material", resource_key: "2", label: "Theirs", url: "/m/2")
    get bookmarks_url
    assert_includes response.body, "Mine"
    assert_not_includes response.body, "Theirs"
  end

  # Create

  test "POST /bookmarks redirects unauthenticated user" do
    post bookmarks_url, params: create_params
    assert_redirected_to new_session_path
  end

  test "POST /bookmarks creates a bookmark for authenticated user" do
    sign_in @user
    assert_difference "Bookmark.count", 1 do
      post bookmarks_url, params: create_params, as: :turbo_stream
    end
    assert_response :success
    bookmark = Bookmark.last
    assert_equal @user,       bookmark.user
    assert_equal "Material",  bookmark.bookmarkable_type
    assert_equal "42",        bookmark.resource_key
  end

  test "POST /bookmarks with JSON format returns bookmark id" do
    sign_in @user
    post bookmarks_url, params: create_params, as: :json
    assert_response :success
    assert_not_nil response.parsed_body["id"]
  end

  test "POST /bookmarks is idempotent — duplicate is ignored" do
    sign_in @user
    Bookmark.create!(user: @user, bookmarkable_type: "Material", resource_key: "42", label: "Kapok", url: "/materials/kapok")
    assert_no_difference "Bookmark.count" do
      post bookmarks_url, params: create_params, as: :turbo_stream
    end
    assert_response :success
  end

  # Destroy

  test "DELETE /bookmarks/:id redirects unauthenticated user" do
    bookmark = Bookmark.create!(user: @user, bookmarkable_type: "Material", resource_key: "42", label: "Kapok", url: "/m/kapok")
    delete bookmark_url(bookmark)
    assert_redirected_to new_session_path
  end

  test "DELETE /bookmarks/:id removes the bookmark" do
    sign_in @user
    bookmark = Bookmark.create!(user: @user, bookmarkable_type: "Material", resource_key: "42", label: "Kapok", url: "/m/kapok")
    assert_difference "Bookmark.count", -1 do
      delete bookmark_url(bookmark), as: :turbo_stream
    end
    assert_response :success
  end

  test "DELETE /bookmarks/:id returns 404 for another user's bookmark" do
    sign_in @user
    other_bookmark = Bookmark.create!(user: @other_user, bookmarkable_type: "Material",
                                      resource_key: "42", label: "Kapok", url: "/m/kapok")
    assert_no_difference "Bookmark.count" do
      delete bookmark_url(other_bookmark), as: :turbo_stream
    end
    assert_response :not_found
  end
end
