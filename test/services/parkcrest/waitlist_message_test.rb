require "test_helper"

class Parkcrest::WaitlistMessageTest < ActiveSupport::TestCase
  test "builds the official FAQ fields from the child and general application" do
    child = Child.new(first_name: "Avery", last_name: "Example", date_of_birth: Date.new(2018, 4, 3))
    application = GeneralApplication.new(child: child, answers: {
      "school_catchment" => "parkcrest",
      "parent_first_name" => "Jamie",
      "parent_last_name" => "Example",
      "parent_phone" => "6045550101"
    })

    message = Parkcrest::WaitlistMessage.new(application).call

    assert_equal "School-age waitlist request for Avery Example", message.fetch("subject")
    assert_includes message.fetch("body"), "Child's full name: Avery Example"
    assert_includes message.fetch("body"), "Child's birthdate: April 3, 2018"
    assert_includes message.fetch("body"), "Parent/guardian's name: Jamie Example"
    assert_includes message.fetch("body"), "Local phone number: 604-555-0101"
  end

  test "rejects a child outside the Parkcrest and Aubrey catchments" do
    child = Child.new(first_name: "Avery", last_name: "Example", date_of_birth: Date.new(2018, 4, 3))
    application = GeneralApplication.new(child: child, answers: { "school_catchment" => "unknown" })

    assert_raises(Parkcrest::WaitlistMessage::Ineligible) do
      Parkcrest::WaitlistMessage.new(application).call
    end
  end
end
