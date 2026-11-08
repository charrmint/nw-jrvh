module Automation
  module Ymca
    class ChildCareWaitlistAdapter
      PROVIDER_KEY = "ymca_bc"
      WORKFLOW_KEY = "child_care_waitlist"
      START_URL = "https://mycommunity.bc.ymca.ca/s/find-child-care"
      STAGES = %w[your_child your_family your_family_guardian_details locations review].freeze
      DEFAULT_POLICY = {
        "provider_specific_priority" => "No",
        "marketing_sms" => "No"
      }.freeze

      class FinalSubmissionForbidden < StandardError; end

      def self.program_type_for(date_of_birth:, on: Date.current)
        age = ((on - date_of_birth).to_i / 365.25).floor
        return "Infant Toddler · Ages 0–3" if age < 3
        return "3 to 5 Years · Ages 3–5" if age < 5

        "School Age · Ages 4–13"
      end

      def self.schedule_choice(value)
        {
          "any_available" => "Any Available Option",
          "full_time" => "Early Years | 5 Days Full Time",
          "part_time" => "Early Years | 3 Days Part Time (M/W/F)",
          "before_school" => "School Age | AM only | 5 Days Full Time",
          "after_school" => "School Age | PM only | 5 Days Full Time",
          "before_and_after_school" => "School Age | AM + PM | 5 Days Full Time"
        }.fetch(value)
      end

      def self.child_identity(snapshot)
        [ snapshot.fetch("child.first_name").to_s.squish.downcase,
          snapshot.fetch("child.last_name").to_s.squish.downcase,
          snapshot.fetch("child.date_of_birth") ]
      end

      def self.submit_application!(experiment: true)
        raise FinalSubmissionForbidden, "YMCA final submission is disabled during experiments" if experiment

        :authorized_for_production_coordinator
      end
    end
  end
end
