require "json"
require "net/http"
require "uri"

module Gmail
  class OauthClient
    AUTHORIZATION_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
    REVOCATION_ENDPOINT = "https://oauth2.googleapis.com/revoke"
    REDIRECT_URI = "http://localhost:3000/gmail/oauth/callback"
    SCOPE = MailboxConnection::GMAIL_SEND_SCOPE

    class Error < StandardError; end

    def authorization_url(state:)
      require_configuration!
      query = URI.encode_www_form(
        client_id: client_id,
        redirect_uri: REDIRECT_URI,
        response_type: "code",
        scope: SCOPE,
        access_type: "offline",
        prompt: "consent",
        state: state
      )
      "#{AUTHORIZATION_ENDPOINT}?#{query}"
    end

    def exchange_code(code)
      response = post_form(TOKEN_ENDPOINT,
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: REDIRECT_URI,
        grant_type: "authorization_code")
      parse_token_response(response, require_refresh_token: true)
    end

    def refresh(refresh_token)
      response = post_form(TOKEN_ENDPOINT,
        refresh_token: refresh_token,
        client_id: client_id,
        client_secret: client_secret,
        grant_type: "refresh_token")
      parse_token_response(response, require_refresh_token: false)
    end

    def revoke(token)
      post_form(REVOCATION_ENDPOINT, token: token)
      true
    rescue Error, Timeout::Error, SocketError, SystemCallError
      false
    end

    private
      def parse_token_response(response, require_refresh_token:)
        body = JSON.parse(response.body)
        raise Error, "Google rejected the OAuth request" unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Google did not grant gmail.send" unless body.fetch("scope", SCOPE).split.include?(SCOPE)
        raise Error, "Google did not return an access token" if body["access_token"].blank?
        if require_refresh_token && body["refresh_token"].blank?
          raise Error, "Google did not return an offline refresh token; disconnect OneKare in your Google Account and try again"
        end

        body.slice("access_token", "refresh_token", "expires_in", "scope")
      rescue JSON::ParserError
        raise Error, "Google returned an invalid OAuth response"
      end

      def post_form(endpoint, fields)
        require_configuration!
        uri = URI(endpoint)
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(fields)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
          http.request(request)
        end
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.warn("Google OAuth request failed status=#{response.code}")
          raise Error, "Google rejected the OAuth request"
        end
        response
      end

      def require_configuration!
        raise Error, "Google OAuth is not configured" if client_id.blank? || client_secret.blank?
      end

      def client_id
        ENV["GOOGLE_OAUTH_CLIENT_ID"]
      end

      def client_secret
        ENV["GOOGLE_OAUTH_CLIENT_SECRET"]
      end
  end
end
