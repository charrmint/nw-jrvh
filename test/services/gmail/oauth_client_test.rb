require "test_helper"

class Gmail::OauthClientTest < ActiveSupport::TestCase
  test "authorization URL requests only gmail.send with offline consent" do
    with_google_configuration do
      uri = URI(Gmail::OauthClient.new.authorization_url(state: "secure-state"))
      query = Rack::Utils.parse_query(uri.query)

      assert_equal MailboxConnection::GMAIL_SEND_SCOPE, query.fetch("scope")
      assert_equal "offline", query.fetch("access_type")
      assert_equal "consent", query.fetch("prompt")
      assert_equal Gmail::OauthClient::REDIRECT_URI, query.fetch("redirect_uri")
      assert_equal "secure-state", query.fetch("state")
    end
  end

  private
    def with_google_configuration
      previous_id = ENV["GOOGLE_OAUTH_CLIENT_ID"]
      previous_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"]
      ENV["GOOGLE_OAUTH_CLIENT_ID"] = "test-client-id"
      ENV["GOOGLE_OAUTH_CLIENT_SECRET"] = "test-client-secret"
      yield
    ensure
      ENV["GOOGLE_OAUTH_CLIENT_ID"] = previous_id
      ENV["GOOGLE_OAUTH_CLIENT_SECRET"] = previous_secret
    end
end
