module Parkcrest
  class WaitlistMessage
    ELIGIBLE_CATCHMENTS = %w[parkcrest aubrey].freeze

    class Ineligible < StandardError; end

    def initialize(general_application)
      @application = general_application
    end

    def call
      validate!
      answers = @application.normalized_answers
      guardian_name = [ answers.fetch("parent.first_name"), answers.fetch("parent.last_name") ].join(" ")
      child_name = [ answers.fetch("child.first_name"), answers.fetch("child.last_name") ].join(" ")
      {
        "subject" => "School-age waitlist request for #{child_name}",
        "body" => <<~BODY.strip
          Hello Parkcrest Child Care Society,

          I would like to request placement on the school-age waitlist.

          Child's full name: #{child_name}
          Child's birthdate: #{Date.iso8601(answers.fetch("child.date_of_birth")).to_fs(:long)}
          Parent/guardian's name: #{guardian_name}
          Local phone number: #{formatted_phone(answers.fetch("parent.local_phone"))}
          School catchment: #{answers.fetch("school.catchment").capitalize}

          Thank you.
        BODY
      }
    end

    private
      def validate!
        catchment = @application.school_catchment
        raise Ineligible, "Parkcrest accepts school-age families only from the Parkcrest or Aubrey catchment" unless ELIGIBLE_CATCHMENTS.include?(catchment)
        raise Ineligible, "A known child birthdate is required" if @application.child.date_of_birth.blank?
        raise Ineligible, "The selected child is not school age" unless @application.school_age?
      end

      def formatted_phone(value)
        value.to_s.gsub(/\A(\d{3})(\d{3})(\d{4})\z/, "\\1-\\2-\\3")
      end
  end
end
