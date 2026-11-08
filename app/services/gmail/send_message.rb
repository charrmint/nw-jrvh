require "base64"
require "json"
require "mail"
require "net/http"

module Gmail
  class SendMessage
    ENDPOINT = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"

    class Rejected < StandardError; end
    class Uncertain < StandardError; end

    def initialize(connection, access_token_service: nil)
      @connection = connection
      @access_token_service = access_token_service || AccessToken.new(connection)
    end

    def call(to:, subject:, body:)
      message = Mail.new
      message.to = to
      message.subject = subject
      message.body = body
      message.content_type = "text/plain; charset=UTF-8"

      uri = URI(ENDPOINT)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@access_token_service.call}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(raw: Base64.urlsafe_encode64(message.to_s, padding: false))
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(request)
      end
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("Gmail send rejected status=#{response.code}")
        raise Rejected, "Gmail rejected the send request"
      end

      result = JSON.parse(response.body)
      raise Uncertain, "Gmail accepted the request without returning a message ID" if result["id"].blank?
      result.fetch("id")
    rescue Gmail::OauthClient::Error => error
      raise Rejected, error.message
    rescue JSON::ParserError, Timeout::Error, SocketError, EOFError, SystemCallError => error
      raise Uncertain, "Gmail send result is uncertain (#{error.class})"
    end
  end
end
