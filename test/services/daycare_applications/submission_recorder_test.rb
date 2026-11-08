require "test_helper"

class DaycareApplications::SubmissionRecorderTest < ActiveSupport::TestCase
  test "refuses to create a record without explicit submission confirmation" do
    recorder = DaycareApplications::SubmissionRecorder.new(
      child: Child.new,
      daycare: Daycare.new
    )

    assert_raises(DaycareApplications::SubmissionRecorder::UnconfirmedSubmission) do
      recorder.call(submitted: true, submission_confirmed: false)
    end
  end
end
