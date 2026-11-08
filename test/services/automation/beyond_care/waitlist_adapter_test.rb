require "test_helper"

class Automation::BeyondCare::WaitlistAdapterTest < ActiveSupport::TestCase
  test "derives only live toddler and preschool categories at requested start" do
    assert_equal "toddler", Automation::BeyondCare::WaitlistAdapter.age_category(
      birth_date: "2024-01-15", requested_start_date: "2026-01-15"
    )
    assert_equal "preschool", Automation::BeyondCare::WaitlistAdapter.age_category(
      birth_date: "2021-01-15", requested_start_date: "2026-01-15"
    )
  end

  test "blocks a child outside the observed age categories" do
    assert_raises Automation::BeyondCare::WaitlistAdapter::EligibilityBlocked do
      Automation::BeyondCare::WaitlistAdapter.age_category(
        birth_date: "2026-11-04", requested_start_date: "2026-11-08"
      )
    end
  end

  test "blocks final submission in experiment mode" do
    assert_raises Automation::BeyondCare::WaitlistAdapter::FinalSubmissionForbidden do
      Automation::BeyondCare::WaitlistAdapter.submit_application!(experiment: true)
    end
  end
end
