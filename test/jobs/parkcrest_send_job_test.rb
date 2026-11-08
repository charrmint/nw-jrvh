require "test_helper"

class ParkcrestSendJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @child = @user.children.create!(first_name: "Avery", last_name: "Example", date_of_birth: Date.new(2018, 4, 3))
    @daycare = Daycare.create!(
      source_facility_id: "parkcrest-test", name: "Parkcrest Child Care Society", city: "Burnaby", postal_code: "V5B 2Z8",
      application_type: "email_only", support_status: "enabled",
      integration_settings: { provider_key: "parkcrest", workflow_key: "school_age_waitlist_email", destination: Parkcrest::Recipient::OFFICIAL }
    )
    @connection = @user.create_mailbox_connection!(
      access_token: "access", refresh_token: "refresh", access_token_expires_at: 1.hour.from_now,
      scope: MailboxConnection::GMAIL_SEND_SCOPE, connected_at: Time.current
    )
    @application = DaycareApplication.create!(
      child: @child, daycare: @daycare, status: "pending", apply_request_id: SecureRandom.uuid,
      prepared_content: { "to" => "controlled@example.com", "subject" => "Test", "body" => "Body" }
    )
  end

  test "records sent only after Gmail returns a message ID and does not resend on retry" do
    calls = 0
    sender = Object.new
    sender.define_singleton_method(:call) do |**|
      calls += 1
      "gmail-message-123"
    end

    Gmail::SendMessage.stub(:new, sender) do
      ParkcrestSendJob.perform_now(@application.id)
      ParkcrestSendJob.perform_now(@application.id)
    end

    assert_equal 1, calls
    assert_equal "waitlist_request_sent", @application.reload.status
    assert_equal "gmail-message-123", @application.provider_application_id
    assert @application.sent_at.present?
  end

  test "marks an ambiguous send uncertain and never retries it" do
    calls = 0
    sender = Object.new
    sender.define_singleton_method(:call) do |**|
      calls += 1
      raise Gmail::SendMessage::Uncertain, "timeout"
    end

    Gmail::SendMessage.stub(:new, sender) do
      ParkcrestSendJob.perform_now(@application.id)
      ParkcrestSendJob.perform_now(@application.id)
    end

    assert_equal 1, calls
    assert_equal "send_uncertain", @application.reload.status
    assert_nil @application.sent_at
  end
end
