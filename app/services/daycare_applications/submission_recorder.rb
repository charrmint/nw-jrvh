module DaycareApplications
  class SubmissionRecorder
    class UnconfirmedSubmission < StandardError; end

    def initialize(child:, daycare:)
      @child = child
      @daycare = daycare
    end

    def call(result)
      result = result.deep_stringify_keys
      unless result["submitted"] == true && result["submission_confirmed"] == true
        raise UnconfirmedSubmission, "Provider submission was not explicitly confirmed"
      end

      application = DaycareApplication.find_or_initialize_by(child: @child, daycare: @daycare)
      application.assign_attributes(
        status: "submitted",
        submitted_at: Time.current,
        provider_application_id: result["provider_application_id"].presence
      )
      application.save!
      application
    end
  end
end
