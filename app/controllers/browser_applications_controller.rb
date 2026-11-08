class BrowserApplicationsController < ApplicationController
  def create
    daycare = Daycare.find(params[:daycare_id])
    raise ActionController::RoutingError, "Not Found" unless daycare.ymca_enabled? || daycare.beyond_care_enabled?

    child = Current.user.children.find(params.require(:child_id))
    general_application = Current.user.general_applications.find_by!(child: child)
    unless child.date_of_birth? && general_application.valid?
      return redirect_to(daycare_path(daycare, child_id: child.id), alert: "Complete this child's profile and general application before applying.")
    end
    if daycare.ymca_enabled? && !Current.user.provider_connections.exists?(provider_key: "ymca")
      return redirect_to(settings_path, alert: "Connect the YMCA account before applying.")
    end

    application = DaycareApplication.create_or_find_by!(child: child, daycare: daycare) do |record|
      record.status = "pending"
      record.apply_request_id = SecureRandom.uuid
      record.prepared_content = {
        "answers" => general_application.normalized_answers,
        "integration_version" => daycare.integration_version
      }
    end

    retry_queued = false
    unless application.previously_new_record?
      application.with_lock do
        if application.status == "submission_failed"
          application.update!(
            status: "pending",
            apply_request_id: SecureRandom.uuid,
            prepared_content: {
              "answers" => general_application.normalized_answers,
              "integration_version" => daycare.integration_version
            },
            last_error: nil
          )
          retry_queued = true
        end
      end
    end

    if application.previously_new_record? || retry_queued
      DaycareApplications::BrowserSubmitJob.perform_later(application.id)
      notice = "Application queued. Its status will update when the provider responds."
    else
      notice = "An application for this child and daycare already exists: #{application.status.humanize}. No duplicate was sent."
    end
    redirect_to daycare_path(daycare, child_id: child.id), notice: notice
  rescue ActiveRecord::RecordNotFound
    redirect_to daycares_path, alert: "Complete the selected child's general application before applying."
  end
end
