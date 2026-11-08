module Gmail
  class AccessToken
    def initialize(connection, oauth_client: OauthClient.new)
      @connection = connection
      @oauth_client = oauth_client
    end

    def call
      return @connection.access_token unless @connection.access_token_expiring?

      @connection.with_lock do
        return @connection.access_token unless @connection.reload.access_token_expiring?

        tokens = @oauth_client.refresh(@connection.refresh_token)
        @connection.update!(
          access_token: tokens.fetch("access_token"),
          access_token_expires_at: tokens.fetch("expires_in", 3600).to_i.seconds.from_now
        )
        @connection.access_token
      end
    end
  end
end
