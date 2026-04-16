require "test_helper"

class MaterialsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get materials_url
    assert_response :success
  end
end
