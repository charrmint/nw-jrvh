require "net/http"

module Integrations
  class MappingSuggester
    class Error < StandardError; end

    SYSTEM_PROMPT = <<~PROMPT.squish.freeze
      Return strict JSON with mappings, defaults, and blockers. Map only to canonical catalog keys.
      Defaults may target only observed controls and must use an observed choice. Provider-specific
      priority and marketing SMS may default to No. Never default an eligibility claim to Yes.
      Do not infer parent answers. Credentials and answer values are never provided.
    PROMPT

    def initialize(host: ENV["DATABRICKS_HOST"], token: ENV["DATABRICKS_TOKEN"], endpoint: ENV["DATABRICKS_MODEL_ENDPOINT"])
      @host = host.to_s.delete_suffix("/")
      @token = token
      @endpoint = endpoint
    end

    def call(inventory:, canonical_catalog:, previous_inventory: nil, allowed_default_policy: {})
      ensure_configured!
      uri = URI("#{@host}/serving-endpoints/#{@endpoint}/invocations")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: JSON.generate(
            inventory: inventory,
            canonical_catalog: canonical_catalog,
            previous_inventory: previous_inventory,
            allowed_default_policy: allowed_default_policy
          ) }
        ],
        temperature: 0.0,
        max_tokens: 3_000
      )

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) { |http| http.request(request) }
      raise Error, "Databricks mapping request failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parse_response(JSON.parse(response.body))
    rescue JSON::ParserError => error
      raise Error, "Databricks returned invalid JSON: #{error.message}"
    end

    private
      def ensure_configured!
        raise Error, "Databricks mapping is not configured" if [ @host, @token, @endpoint ].any?(&:blank?)
      end

      def parse_response(response)
        content = response.dig("choices", 0, "message", "content") || response.dig("predictions", 0, "content") || response.dig("predictions", 0)
        content = content.gsub(/\A```(?:json)?\s*|\s*```\z/, "") if content.is_a?(String)
        content.is_a?(String) ? JSON.parse(content) : content
      end
  end
end
