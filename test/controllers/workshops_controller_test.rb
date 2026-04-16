require "test_helper"

class WorkshopsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get workshops_url
    assert_response :success
  end
end
