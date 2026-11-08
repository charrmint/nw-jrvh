module Parkcrest
  class Recipient
    OFFICIAL = "info@parkcrestchildcaresociety.ca"

    class MissingTestRecipient < StandardError; end

    def self.for(daycare)
      return OFFICIAL if Rails.env.production? && daycare.parkcrest_integration_settings&.fetch("destination", nil) == OFFICIAL

      recipient = ENV["PARKCREST_TEST_RECIPIENT"].to_s.strip
      raise MissingTestRecipient, "PARKCREST_TEST_RECIPIENT must be configured for non-production sends" if recipient.blank?
      raise MissingTestRecipient, "Development sends may not use Parkcrest's address" if recipient.casecmp?(OFFICIAL)

      recipient
    end
  end
end
