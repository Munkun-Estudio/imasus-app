require "test_helper"

class PrototypeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get prototype_index_url
    assert_response :success
  end
end
