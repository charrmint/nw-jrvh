class ParkcrestSendJob < ApplicationJob
  queue_as :default

  def perform(application_id)
    application = DaycareApplication.find(application_id)
    claimed = application.with_lock do
      next false unless application.status == "pending"

      application.update!(status: "sending", last_error: nil)
      true
    end
    return unless claimed

    connection = application.child.user.mailbox_connection
    unless connection
      application.update!(status: "send_failed", last_error: "Gmail is disconnected")
      return
    end

    content = application.prepared_content
    message_id = Gmail::SendMessage.new(connection).call(
      to: content.fetch("to"), subject: content.fetch("subject"), body: content.fetch("body")
    )
    application.update!(
      status: "waitlist_request_sent",
      sent_at: Time.current,
      provider_application_id: message_id,
      last_error: nil
    )
  rescue Gmail::SendMessage::Rejected => error
    application&.update!(status: "send_failed", last_error: error.message)
  rescue Gmail::SendMessage::Uncertain => error
    application&.update!(status: "send_uncertain", last_error: error.message)
  rescue StandardError => error
    Rails.logger.error("Parkcrest send stopped without retry application_id=#{application_id} error=#{error.class}")
    application&.update!(status: "send_uncertain", last_error: "Send stopped unexpectedly; not retried") if application&.status == "sending"
  end
end
