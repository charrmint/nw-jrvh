require "uri"

module DaycaresHelper
  # Returns [url, label, official?] for linking to a daycare's site.
  # Uses the daycare's own website when it reports one (adding https:// if the data left it off);
  # otherwise falls back to a web search for the daycare so there is always a link.
  def daycare_site_link(daycare)
    url = daycare_website_url(daycare)
    return [ url, "Visit website", true ] if url

    query = [ daycare.name, daycare.address, daycare.city, "daycare" ].compact_blank.join(" ")
    [ "https://www.google.com/search?q=#{ERB::Util.url_encode(query)}", "Search the web", false ]
  end

  private
    def daycare_website_url(daycare)
      return daycare.website_link_url if daycare.website_link_url.present?

      raw = daycare.website_url.to_s.strip
      return if raw.blank?

      candidate = raw.match?(/\A[a-z][a-z0-9+.-]*:/i) ? raw : "https://#{raw}"
      uri = URI.parse(candidate)
      candidate if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end
end