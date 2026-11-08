module Automation
  module BeyondCare
    class WaitlistAdapter
      PROVIDER_KEY = "beyond_care"
      WORKFLOW_KEY = "public_waitlist"
      DEFAULT_POLICY = {}.freeze

      class FinalSubmissionForbidden < StandardError; end
      class EligibilityBlocked < StandardError; end

      def self.age_category(birth_date:, requested_start_date:)
        born = Date.iso8601(birth_date)
        starts = Date.iso8601(requested_start_date)
        months = (starts.year - born.year) * 12 + starts.month - born.month
        months -= 1 if starts.day < born.day
        return "toddler" if months.between?(18, 35)
        return "preschool" if months.between?(36, 71)

        raise EligibilityBlocked,
          "Child is outside the observed 18-month-to-5-year age categories at requested start"
      end

      def self.submit_application!(experiment: true)
        raise FinalSubmissionForbidden, "Beyond Care final submission is disabled during experiments" if experiment
      end
    end
  end
end
