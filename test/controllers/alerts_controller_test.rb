require "test_helper"

class AlertsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get alerts_index_url
    assert_response :success
  end

  test "should get new" do
    get alerts_new_url
    assert_response :success
  end

  test "should get edit" do
    get alerts_edit_url
    assert_response :success
  end
end
