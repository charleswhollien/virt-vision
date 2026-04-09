require "test_helper"

class VmsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get vms_index_url
    assert_response :success
  end

  test "should get show" do
    get vms_show_url
    assert_response :success
  end
end
