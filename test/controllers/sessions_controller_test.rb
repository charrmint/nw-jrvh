require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get login_path
    assert_response :success
  end

  test "new redirects signed-in users" do
    sign_in_as @user
    get login_path
    assert_redirected_to root_path
  end

  test "create with valid credentials" do
    assert_difference "Session.count", 1 do
      post session_path, params: { email_address: @user.email_address, password: "password" }
    end

    assert_response :see_other
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to login_path
    assert_nil cookies[:session_id]
  end

  test "create with unknown email shows the same message" do
    post session_path, params: { email_address: "missing@example.com", password: "wrong" }
    follow_redirect!
    assert_select "div", /Try another email address or password/
  end

  test "destroy" do
    sign_in_as @user

    assert_difference "Session.count", -1 do
      delete session_path
    end

    assert_response :see_other
    assert_redirected_to login_path
    assert_empty cookies[:session_id]
  end
end
