require "digest"

module Automation
  class FieldInventory
    attr_reader :document

    def initialize(document)
      @document = canonicalize(document.deep_stringify_keys)
    end

    def fingerprint
      Digest::SHA256.hexdigest(JSON.generate(document))
    end

    private
      def canonicalize(value)
        case value
        when Hash
          value.keys.sort.index_with { |key| canonicalize(value.fetch(key)) }
        when Array
          value.map { |item| canonicalize(item) }
        else
          value
        end
      end
  end
end
