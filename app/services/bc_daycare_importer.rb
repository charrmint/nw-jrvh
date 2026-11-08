require "csv"
require "net/http"
require "set"
require "uri"

class BcDaycareImporter
  SOURCE_URL = "https://catalogue.data.gov.bc.ca/dataset/4cc207cc-ff03-44f8-8c5f-415af5224646/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39/download/childcare_locations.csv"
  MAX_REDIRECTS = 5
  BATCH_SIZE = 500

  IMPORTED_COLUMNS = %i[
    name address city postal_code latitude longitude website_url phone care_types
    services reported_vacancies vacancy_updated_at
  ].freeze

  REQUIRED_HEADERS = %w[
    FAC_PARTY_ID SERVICE_TYPE_CD NAME ADDRESS_1 ADDRESS_2 CITY POSTAL_CODE
    LATITUDE LONGITUDE PHONE WEBSITE EMAIL OP_WEEKDAY_YN OP_WEEKEND_YN
    OP_STAT_HOLIDAY_YN OP_OVERNIGHT_YN OP_EXT_WEEKDAY_BEFORE6AM_YN
    OP_EXT_WEEKDAY_AFTER7PM_YN SRVC_UNDER36_YN SRVC_30MOS_5YRS_YN
    SRVC_LICPRE_YN SRVC_OOS_KINDER_YN SRVC_OOS_GR1_AGE12_YN
    LANG_CANTONESE_YN LANG_PUNJABI_YN LANG_MANDARIN_YN LANG_FRENCH_YN
    LANG_SPANISH_YN LANG_OTHER_YN PROVIDE_CD_MEALS PROVIDE_CD_PICKUP
    PRESCHOOL_MORNING_YN PRESCHOOL_MIDDAY_YN PRESCHOOL_AFTERNOON_YN
    ABORIGINAL_PROGRAMMING_YN ACCOMMODATE_SPECIAL_NEEDS ECE_CERTIFICATION_YN
    ELF_PROGRAMMING_YN VACANCY_SRVC_UNDER36 VACANCY_SRVC_30MOS_5YRS
    VACANCY_SRVC_LICPRE VACANCY_SRVC_OOS_GR1_AGE12 VACANCY_LAST_UPDATE
    HA_FAC_INSPEC_RPTS IS_INCOMPLETE_IND IS_CCFRI_AUTH IS_DUPLICATE
  ].freeze

  CARE_TYPES = {
    "SRVC_UNDER36_YN" => [ "under_36_months", "Under 36 months" ],
    "SRVC_30MOS_5YRS_YN" => [ "30_months_to_5_years", "30 months to 5 years" ],
    "SRVC_LICPRE_YN" => [ "licensed_preschool", "Licensed preschool" ],
    "SRVC_OOS_KINDER_YN" => [ "out_of_school_kindergarten", "Out-of-school care (kindergarten)" ],
    "SRVC_OOS_GR1_AGE12_YN" => [ "out_of_school_grade_1_to_12", "Out-of-school care (grade 1 to age 12)" ]
  }.freeze

  VACANCIES = {
    "VACANCY_SRVC_UNDER36" => [ "under_36_months", "Under 36 months" ],
    "VACANCY_SRVC_30MOS_5YRS" => [ "30_months_to_5_years", "30 months to 5 years" ],
    "VACANCY_SRVC_LICPRE" => [ "licensed_preschool", "Licensed preschool" ],
    "VACANCY_SRVC_OOS_GR1_AGE12" => [ "out_of_school_grade_1_to_12", "Out-of-school care (grade 1 to age 12)" ]
  }.freeze

  Result = Data.define(:created, :updated, :rejected)

  class DownloadError < StandardError; end
  class InvalidDownload < StandardError; end
  class InvalidConfiguration < StandardError; end

  def self.call(output: $stdout)
    new(output: output).call
  end

  def initialize(output:)
    @output = output
  end

  def call
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    log "Starting import."
    rows = download_and_validate
    rows = filter_rows(rows)

    log "Preparing #{rows.length} selected rows."
    prepared_rows, source_rejections, invalid_rejections = prepare_rows(rows)
    rejected = source_rejections + invalid_rejections
    log "Prepared #{prepared_rows.length} rows; rejected #{rejected} " \
      "(source flags: #{source_rejections}, invalid data: #{invalid_rejections})."

    facility_ids = prepared_rows.pluck(:source_facility_id)
    log "Loading existing facility identifiers."
    existing_ids = Daycare.where(source_facility_id: facility_ids).pluck(:source_facility_id).to_set
    created = facility_ids.count { |facility_id| !existing_ids.include?(facility_id) }
    updated = prepared_rows.length - created
    log "Import plan: create #{created}, update #{updated}, reject #{rejected}."

    if prepared_rows.any?
      batch_count = (prepared_rows.length.to_f / BATCH_SIZE).ceil

      begin
        Daycare.transaction do
          prepared_rows.each_slice(BATCH_SIZE).with_index do |batch, index|
            log "Writing batch #{index + 1}/#{batch_count} (#{batch.length} rows)."
            Daycare.upsert_all(
              batch,
              unique_by: :index_daycares_on_source_facility_id,
              update_only: IMPORTED_COLUMNS,
              record_timestamps: true
            )
            log "Finished batch #{index + 1}/#{batch_count}."
          end

          log "All batches written; committing transaction."
        end
      rescue StandardError => error
        log "Database write failed; transaction rolled back (#{error.class})."
        raise
      end
    else
      log "No valid rows selected; nothing to write."
    end

    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    log "Import committed in #{duration.round(1)} seconds."
    Result.new(created: created, updated: updated, rejected: rejected)
  end

  private
    def download_and_validate
      log "Downloading official BC childcare CSV."
      body = download(URI(SOURCE_URL))
      log "Downloaded #{body.bytesize} bytes; validating CSV."
      body.force_encoding(Encoding::UTF_8)
      raise InvalidDownload, "download is not valid UTF-8" unless body.valid_encoding?

      table = CSV.parse(body.delete_prefix("\uFEFF"), headers: true)
      headers = table.headers
      missing_headers = REQUIRED_HEADERS - headers

      raise InvalidDownload, "download has duplicate headers" unless headers.uniq.length == headers.length
      raise InvalidDownload, "download is missing headers: #{missing_headers.join(', ')}" if missing_headers.any?
      raise InvalidDownload, "download contains no daycare records" if table.empty?
      raise InvalidDownload, "download contains a row with the wrong number of columns" if table.any? { |row| row.fields.length != headers.length }

      facility_ids = table.map { |row| value(row, "FAC_PARTY_ID") }
      raise InvalidDownload, "download contains a blank facility identifier" if facility_ids.any?(&:nil?)
      raise InvalidDownload, "download contains duplicate facility identifiers" unless facility_ids.uniq.length == facility_ids.length

      log "Validated #{table.length} CSV rows and #{headers.length} columns."
      table
    rescue CSV::MalformedCSVError => error
      raise InvalidDownload, "download is not valid CSV: #{error.message}"
    end

    def download(uri, redirects_remaining = MAX_REDIRECTS)
      raise DownloadError, "source URL must use HTTPS" unless uri.is_a?(URI::HTTPS)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
        http.request(Net::HTTP::Get.new(uri.request_uri, "Accept" => "text/csv,text/plain"))
      end

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        raise DownloadError, "too many redirects" if redirects_remaining.zero?

        download(URI.join(uri, response.fetch("location")), redirects_remaining - 1)
      else
        raise DownloadError, "download failed with HTTP #{response.code}"
      end
    rescue SocketError, SystemCallError, Timeout::Error => error
      raise DownloadError, "download failed: #{error.message}"
    end

    def rejected_source_row?(row)
      row["IS_DUPLICATE"] == "Y" || row["IS_INCOMPLETE_IND"] == "Y"
    end

    def filter_rows(rows)
      raw_facility_ids = ENV["BC_DAYCARE_FACILITY_IDS"].to_s
      return rows if raw_facility_ids.blank?

      facility_ids = raw_facility_ids.split(",").map(&:strip).reject(&:blank?).to_set
      raise InvalidConfiguration, "BC_DAYCARE_FACILITY_IDS contains no facility identifiers" if facility_ids.empty?

      source_ids = rows.map { |row| row["FAC_PARTY_ID"] }.to_set
      missing_ids = facility_ids - source_ids
      if missing_ids.any?
        raise InvalidConfiguration,
          "BC_DAYCARE_FACILITY_IDS contains identifiers absent from the download: #{missing_ids.to_a.sort.join(', ')}"
      end

      log "Applying facility allowlist with #{facility_ids.length} identifiers."
      rows.select { |row| facility_ids.include?(row["FAC_PARTY_ID"]) }
    end

    def prepare_rows(rows)
      prepared_rows = []
      source_rejections = 0
      invalid_rejections = 0

      rows.each do |row|
        if rejected_source_row?(row)
          source_rejections += 1
          next
        end

        prepared_rows << imported_attributes(row).merge(
          source_facility_id: required_value(row, "FAC_PARTY_ID")
        )
      rescue ArgumentError
        invalid_rejections += 1
      end

      [ prepared_rows, source_rejections, invalid_rejections ]
    end

    def imported_attributes(row)
      {
        name: required_value(row, "NAME").squish,
        address: [ value(row, "ADDRESS_1"), value(row, "ADDRESS_2") ].compact.join(", ").squish.presence,
        city: required_value(row, "CITY").squish,
        postal_code: required_value(row, "POSTAL_CODE").squish.upcase,
        latitude: decimal(row, "LATITUDE"),
        longitude: decimal(row, "LONGITUDE"),
        website_url: website_url(row["WEBSITE"]),
        phone: value(row, "PHONE"),
        care_types: care_types(row),
        services: services(row),
        reported_vacancies: reported_vacancies(row),
        vacancy_updated_at: vacancy_updated_at(row)
      }
    end

    def care_types(row)
      CARE_TYPES.filter_map do |column, (key, label)|
        { "key" => key, "label" => label } if row[column] == "Y"
      end
    end

    def reported_vacancies(row)
      VACANCIES.to_h do |column, (key, label)|
        [ key, { "label" => label, "available" => row[column] == "Y" } ]
      end
    end

    def services(row)
      {
        "facility_type" => required_value(row, "SERVICE_TYPE_CD"),
        "contact_email" => value(row, "EMAIL"),
        "operations" => selected_labels(row, {
          "OP_WEEKDAY_YN" => "Weekdays",
          "OP_WEEKEND_YN" => "Weekends",
          "OP_STAT_HOLIDAY_YN" => "Statutory holidays",
          "OP_OVERNIGHT_YN" => "Overnight",
          "OP_EXT_WEEKDAY_BEFORE6AM_YN" => "Weekdays before 6 a.m.",
          "OP_EXT_WEEKDAY_AFTER7PM_YN" => "Weekdays after 7 p.m."
        }),
        "languages" => selected_labels(row, {
          "LANG_CANTONESE_YN" => "Cantonese",
          "LANG_PUNJABI_YN" => "Punjabi",
          "LANG_MANDARIN_YN" => "Mandarin",
          "LANG_FRENCH_YN" => "French",
          "LANG_SPANISH_YN" => "Spanish",
          "LANG_OTHER_YN" => "Other"
        }),
        "meals" => value(row, "PROVIDE_CD_MEALS"),
        "pickup" => value(row, "PROVIDE_CD_PICKUP"),
        "preschool_sessions" => selected_labels(row, {
          "PRESCHOOL_MORNING_YN" => "Morning",
          "PRESCHOOL_MIDDAY_YN" => "Midday",
          "PRESCHOOL_AFTERNOON_YN" => "Afternoon"
        }),
        "aboriginal_programming" => row["ABORIGINAL_PROGRAMMING_YN"] == "Y",
        "accommodates_special_needs" => row["ACCOMMODATE_SPECIAL_NEEDS"] == "Y",
        "ece_certification" => row["ECE_CERTIFICATION_YN"] == "Y",
        "elf_programming" => row["ELF_PROGRAMMING_YN"] == "Y",
        "ccfri_authorized" => row["IS_CCFRI_AUTH"] == "Y",
        "inspection_reports_url" => value(row, "HA_FAC_INSPEC_RPTS")
      }.compact
    end

    def selected_labels(row, mapping)
      mapping.filter_map { |column, label| label if row[column] == "Y" }
    end

    def vacancy_updated_at(row)
      date = value(row, "VACANCY_LAST_UPDATE")
      Date.strptime(date, "%Y/%m/%d") if date
    end

    def decimal(row, column)
      raw_value = value(row, column)
      BigDecimal(raw_value) if raw_value
    end

    def website_url(raw_value)
      url = raw_value.to_s.strip
      return if url.empty?

      url = "https://#{url}" unless url.match?(%r{\Ahttps?://}i)
      uri = URI.parse(url)
      uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end

    def required_value(row, column)
      value(row, column) || raise(ArgumentError, "#{column} is blank")
    end

    def value(row, column)
      row[column].to_s.strip.presence
    end

    def log(message)
      @output.puts "[BC daycare import] #{message}"
      @output.flush if @output.respond_to?(:flush)
    end
end
