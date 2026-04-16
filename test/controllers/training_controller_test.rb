require "test_helper"

class TrainingControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get training_index_url
    assert_response :success
  end
end
