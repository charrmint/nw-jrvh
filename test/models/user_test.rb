require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**attributes)
    User.new({
      full_name: "New Parent",
      email_address: "new@example.com",
      phone_number: "604-555-0199",
      password: "long enough password",
      password_confirmation: "long enough password"
    }.merge(attributes))
  end

  test "valid with all required attributes" do
    assert build_user.valid?
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "email_address is unique regardless of case" do
    user = build_user(email_address: "ONE@example.com")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "rejects malformed email_address" do
    assert_not build_user(email_address: "not-an-email").valid?
  end

  test "requires full_name and squishes whitespace" do
    assert_not build_user(full_name: "  ").valid?
    assert_equal "Jane Doe", build_user(full_name: "  Jane   Doe ").full_name
  end

  test "normalizes phone_number to 10 digits" do
    assert_equal "6045551234", build_user(phone_number: "(604) 555-1234").phone_number
    assert_equal "6045551234", build_user(phone_number: "+1 604 555 1234").phone_number
  end

  test "rejects phone numbers that are not 10 digits" do
    assert_not build_user(phone_number: "604555123").valid?
    assert_not build_user(phone_number: "").valid?
  end

  test "requires a password of at least 12 characters" do
    assert_not build_user(password: "short", password_confirmation: "short").valid?
  end

  test "requires matching password confirmation" do
    assert_not build_user(password_confirmation: "something else").valid?
  end
end
