require "uri"

class Daycare < ApplicationRecord
  APPLICATION_TYPES = %w[ external public_form authenticated_portal email_only ].freeze
  SUPPORT_STATUSES = %w[ unconfigured enabled needs_validation paused ].freeze

  has_many :daycare_applications, dependent: :restrict_with_error

  normalizes :name, :city, with: ->(value) { value.squish }
  normalizes :postal_code, with: ->(value) { value.squish.upcase }

  validates :source_facility_id, presence: true, uniqueness: true
  validates :name, :city, :postal_code, presence: true
  validates :application_type, inclusion: { in: APPLICATION_TYPES }
  validates :support_status, inclusion: { in: SUPPORT_STATUSES }

  scope :alphabetical, -> { order(:name, :city) }

  def contact_email
    services["contact_email"]
  end

  def website_link_url
    safe_http_url(website_url)
  end

  def application_link_url
    safe_http_url(application_url)
  end

  def ymca_integration_settings
    settings = integration_settings.deep_stringify_keys
    return unless support_status == "enabled" && settings["provider_key"] == "ymca_bc"

    settings
  end

  def ymca_enabled?
    ymca_integration_settings.present?
  end

  def beyond_care_integration_settings
    settings = integration_settings.deep_stringify_keys
    return unless %w[needs_validation enabled].include?(support_status)
    return unless settings["provider_key"] == "beyond_care"

    settings
  end

  def beyond_care_enabled?
    support_status == "enabled" && beyond_care_integration_settings.present? &&
      beyond_care_integration_settings["submit_enabled"] == true
  end

  def beyond_care_experiment_available?
    beyond_care_integration_settings.present?
  end

  def parkcrest_integration_settings
    settings = integration_settings.deep_stringify_keys
    return unless support_status == "enabled" && application_type == "email_only"
    return unless settings["provider_key"] == "parkcrest"

    settings
  end

  def parkcrest_enabled?
    parkcrest_integration_settings.present?
  end

  def self.search(name: nil, city: nil, postal_code: nil)
    result = all
    result = result.where("name ILIKE ?", "%#{sanitize_sql_like(name.strip)}%") if name.present?
    result = result.where("city ILIKE ?", "%#{sanitize_sql_like(city.strip)}%") if city.present?

    if postal_code.present?
      normalized_postal_code = postal_code.gsub(/\s+/, "")
      result = result.where("REPLACE(postal_code, ' ', '') ILIKE ?", "%#{sanitize_sql_like(normalized_postal_code)}%")
    end

    result
  end

  private
    def safe_http_url(value)
      uri = URI.parse(value.to_s)
      uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end
end
