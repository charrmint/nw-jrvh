require "test_helper"

class Automation::Ymca::ChildCareWaitlistAdapterTest < ActiveSupport::TestCase
  test "maps the MVP full-time schedule deterministically" do
    assert_equal "Early Years | 5 Days Full Time",
      Automation::Ymca::ChildCareWaitlistAdapter.schedule_choice("full_time")
  end

  test "normalizes child identity for duplicate prevention" do
    snapshot = {
      "child.first_name" => " Josh ",
      "child.last_name" => "JOSHIE",
      "child.date_of_birth" => "2026-11-04"
    }

    assert_equal [ "josh", "joshie", "2026-11-04" ],
      Automation::Ymca::ChildCareWaitlistAdapter.child_identity(snapshot)
  end

  test "blocks final submission in experiment mode" do
    assert_raises Automation::Ymca::ChildCareWaitlistAdapter::FinalSubmissionForbidden do
      Automation::Ymca::ChildCareWaitlistAdapter.submit_application!(experiment: true)
    end
  end
end
