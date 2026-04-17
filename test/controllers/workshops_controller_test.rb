require "test_helper"

class WorkshopsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
    @workshop = Workshop.create!(title: "IMASUS Greece", location: "Athens")
    @participant = User.create!(name: "Part", email: "part@example.com", password: @password, role: :participant)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "should get index" do
    get workshops_url
    assert_response :success
  end

  test "show requires login" do
    get workshop_url(@workshop)
    assert_redirected_to new_session_path
  end

  test "signed-in user can view show" do
    sign_in(@participant)
    get workshop_url(@workshop)
    assert_response :success
    assert_select "h1", text: @workshop.title
  end
end
