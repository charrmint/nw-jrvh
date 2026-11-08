class ParkcrestApplicationsController < ApplicationController
  def create
    daycare = Daycare.find(params[:daycare_id])
    raise ActionController::RoutingError, "Not Found" unless daycare.parkcrest_enabled?

    child = Current.user.children.find(params.require(:child_id))
    general_application = Current.user.general_applications.find_by!(child: child)
    connection = Current.user.mailbox_connection
    return redirect_to(settings_path, alert: "Connect Gmail before applying to Parkcrest.") unless connection

    message = Parkcrest::WaitlistMessage.new(general_application).call
    prepared_content = message.merge("to" => Parkcrest::Recipient.for(daycare))
    application = DaycareApplication.create_or_find_by!(child: child, daycare: daycare) do |record|
      record.status = "pending"
      record.apply_request_id = SecureRandom.uuid
      record.prepared_content = prepared_content
    end

    if application.previously_new_record?
      ParkcrestSendJob.perform_later(application.id)
      notice = "Waitlist request queued for sending. The status below updates automatically."
    else
      notice = status_message(application)
    end
    redirect_to daycare_path(daycare, child_id: child.id), notice: notice
  rescue ActiveRecord::RecordNotFound
    redirect_to daycares_path, alert: "Complete the selected child's general application before applying."
  rescue Parkcrest::WaitlistMessage::Ineligible, Parkcrest::Recipient::MissingTestRecipient => error
    redirect_to daycare_path(params[:daycare_id], child_id: params[:child_id]), alert: error.message
  end

  private
    def status_message(application)
      case application.status
      when "waitlist_request_sent" then "Waitlist request sent. This does not confirm waitlist membership."
      when "send_failed" then "The prior Gmail send was rejected and was not retried."
      when "send_uncertain" then "The prior send result is uncertain and was not retried to avoid a duplicate."
      else "A waitlist request is already being processed; no duplicate was sent."
      end
    end
end
