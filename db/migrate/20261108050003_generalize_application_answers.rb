class GeneralizeApplicationAnswers < ActiveRecord::Migration[8.1]
  AFFILIATION_LABELS = {
    "ymca_employee" => "YMCA BC employee",
    "vch_employee" => "Vancouver Coastal Health employee",
    "phsa_employee" => "PHSA employee",
    "una_or_ubc" => "UNA employee or UBC resident",
    "surrey_city_hall" => "City of Surrey employee at Surrey City Hall",
    "broadway_tech" => "Broadway Tech Building employee",
    "northern_health" => "Northern Health employee",
    "bc_hydro" => "BC Hydro employee",
    "school_district_60" => "School District 60 employee",
    "northern_lights_college" => "Northern Lights College student or employee",
    "kamloops_employee" => "City of Kamloops employee"
  }.freeze

  CATEGORY_MAPPING = {
    "young_parent" => "young_parent_program",
    "support_program" => "community_support_program",
    "ywca_staff" => "child_care_employee",
    "transfer_child" => "transferring_care",
    "sibling_current" => "sibling_current",
    "sibling_alumni" => "sibling_alumni"
  }.freeze

  def up
    legacy_application = Class.new(ActiveRecord::Base) do
      self.table_name = "general_applications"
    end

    legacy_application.find_each do |application|
      answers = application.answers.deep_dup

      unless answers.key?("school_catchment")
        answers["school_catchment"] = case answers["parkcrest_catchment"]
        when "parkcrest", "aubrey" then answers["parkcrest_catchment"]
        else
          if answers["cascade_inman_catchment"] == "yes"
            "cascade_or_inman"
          elsif answers["parkcrest_catchment"] == "neither" || answers["cascade_inman_catchment"] == "no"
            "other"
          else
            "unknown"
          end
        end
      end

      answers["affiliations_text"] ||= Array(answers["ymca_affiliations"]).filter_map { |value| AFFILIATION_LABELS[value] }.join(", ")
      answers["affiliations_confirmed"] ||= answers["ymca_affiliations_confirmed"]
      answers["categories"] ||= Array(answers["ywca_categories"]).filter_map { |value| CATEGORY_MAPPING[value] }.uniq
      answers["categories_confirmed"] ||= answers["ywca_categories_confirmed"]
      # Prior YMCA SMS consent does not imply consent to OneKare SMS.
      answers["application_sms_consent"] ||= "0"

      application.update_columns(answers: answers)
    end
  end

  def down
    # Preserve answers collected under the new general fields.
  end
end
