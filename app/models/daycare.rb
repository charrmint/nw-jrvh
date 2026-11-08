require "uri"

class Daycare < ApplicationRecord
  APPLICATION_TYPES = %w[ external public_form authenticated_portal email_only ].freeze
  SUPPORT_STATUSES = %w[ unconfigured enabled needs_validation paused ].freeze

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
