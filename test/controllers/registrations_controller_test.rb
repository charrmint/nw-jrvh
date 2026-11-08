require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def valid_params
    {
      user: {
        full_name: "New Parent",
        email_address: "new@example.com",
        phone_number: "(604) 555-0199",
        password: "long enough password",
        password_confirmation: "long enough password"
      }
    }
  end

  test "new" do
    get sign_up_path
    assert_response :success
  end

  test "new redirects signed-in users" do
    sign_in_as users(:one)
    get sign_up_path
    assert_redirected_to root_path
  end

  test "create signs up and signs in" do
    assert_difference [ "User.count", "Session.count" ], 1 do
      post registrations_path, params: valid_params
    end

    assert_response :see_other
    assert_redirected_to root_path
    assert cookies[:session_id]

    user = User.find_by!(email_address: "new@example.com")
    assert_equal "6045550199", user.phone_number
  end

  test "create with invalid params re-renders with 422" do
    params = valid_params.deep_merge(user: { phone_number: "123" })

    assert_no_difference "User.count" do
      post registrations_path, params: params
    end

    assert_response :unprocessable_content
    assert_select "li", /Phone number/
  end

  test "create ignores unpermitted attributes" do
    post registrations_path, params: valid_params.deep_merge(user: { id: 999_999 })
    assert_not_equal 999_999, User.find_by!(email_address: "new@example.com").id
  end
end
