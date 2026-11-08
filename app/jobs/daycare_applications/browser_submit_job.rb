module DaycareApplications
  class BrowserSubmitJob < ApplicationJob
    queue_as :default

    def perform(application_id)
      runner_started = false
      application = DaycareApplication.find(application_id)
      claimed = application.with_lock do
        next false unless application.status == "pending"

        application.update!(status: "sending", last_error: nil)
        true
      end
      return unless claimed

      child = application.child
      daycare = application.daycare
      unless application.prepared_content.fetch("integration_version") == daycare.integration_version
        raise "Browser integration changed after the parent clicked Apply automatically"
      end
      snapshot = application.prepared_content.fetch("answers")
      runner = if daycare.ymca_enabled?
        Automation::Ymca::ExperimentRunner.new(child: child, daycare: daycare, snapshot: snapshot, submit: true)
      elsif daycare.beyond_care_enabled?
        Automation::BeyondCare::ExperimentRunner.new(child: child, daycare: daycare, snapshot: snapshot, submit: true)
      else
        raise "Browser submission configuration is disabled"
      end

      runner_started = true
      result = runner.call
      if result["submitted"] == true && result["submission_confirmed"] == true
        SubmissionRecorder.new(child: child, daycare: daycare).call(result)
      elsif result["submission_attempted"] == true
        application.update!(status: "submission_uncertain", last_error: "Final submission was attempted; provider confirmation was not observed")
      else
        application.update!(status: "submission_failed", last_error: "Provider form could not be completed before submission")
      end
    rescue Automation::Ymca::ExperimentRunner::Error, Automation::BeyondCare::ExperimentRunner::Error => error
      state = error.result["submission_attempted"] == true ? "submission_uncertain" : "submission_failed"
      application&.update!(status: state, last_error: error.message) if application&.status == "sending"
    rescue StandardError => error
      Rails.logger.error("Browser submission stopped application_id=#{application_id} error=#{error.class}")
      if application&.status == "sending"
        state = runner_started ? "submission_uncertain" : "submission_failed"
        application.update!(status: state, last_error: "Submission stopped unexpectedly; check the provider before trying again")
      end
    end
  end
end
