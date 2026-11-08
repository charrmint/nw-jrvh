require "test_helper"

class MailboxConnectionTest < ActiveSupport::TestCase
  test "encrypts Gmail tokens at rest" do
    connection = MailboxConnection.new
    connection.access_token = "access-token-value"
    connection.refresh_token = "refresh-token-value"

    refute_includes connection.encrypted_access_token, "access-token-value"
    refute_includes connection.encrypted_refresh_token, "refresh-token-value"
    assert_equal "access-token-value", connection.access_token
    assert_equal "refresh-token-value", connection.refresh_token
  end
end
