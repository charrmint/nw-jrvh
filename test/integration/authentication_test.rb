require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  class ProtectedController < ApplicationController
    def show
      render plain: "Hello #{Current.user.full_name}"
    end
  end

  test "home is public" do
    get root_path
    assert_response :success
    assert_select "a", "Sign up"
  end

  test "home shows the signed-in parent" do
    sign_in_as users(:one)
    get root_path
    assert_select "p", /Parent One/
  end

  test "protected routes redirect anonymous users to login and return after login" do
    with_protected_route do
      get "/protected"
      assert_redirected_to login_path

      post session_path, params: { email_address: users(:one).email_address, password: "password" }
      assert_redirected_to "http://www.example.com/protected"

      follow_redirect!
      assert_equal "Hello Parent One", response.body
    end
  end

  test "sessions older than the lifetime are rejected and deleted" do
    with_protected_route do
      sign_in_as users(:one)
      Current.session.update!(created_at: (Authentication::SESSION_LIFETIME + 1.day).ago)

      assert_difference "Session.count", -1 do
        get "/protected"
      end
      assert_redirected_to login_path
    end
  end

  test "logout requires authentication" do
    delete session_path
    assert_redirected_to login_path
  end

  private
    def with_protected_route(&block)
      with_routing do |set|
        set.draw do
          root "pages#home"
          get "protected", to: "authentication_test/protected#show"
          get "login", to: "sessions#new", as: :login
          resource :session, only: %i[ create destroy ]
        end
        block.call
      end
    end
end
