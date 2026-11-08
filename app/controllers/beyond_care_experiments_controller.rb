class BeyondCareExperimentsController < ApplicationController
  def create
    daycare = Daycare.find(params[:daycare_id])
    child = Current.user.children.includes(:general_application).find(params.require(:child_id))

    result = Automation::BeyondCare::ExperimentRunner.new(child:, daycare:).call
    redirect_with_result(daycare:, child:, result:)
  rescue Automation::BeyondCare::ExperimentRunner::Error => error
    redirect_to daycare_path(params[:daycare_id], child_id: params[:child_id]), alert: error.message
  end

  private
    def redirect_with_result(daycare:, child:, result:)
      destination = daycare_path(daycare, child_id: child.id)
      case result["status"]
      when "filled_unsent"
        redirect_to destination, notice: "Beyond Care application was filled without submitting."
      when "eligibility_blocked"
        redirect_to destination,
          alert: "Beyond Care application was not submitted: the child is outside the form's age categories at the requested start date."
      when "verification_required"
        redirect_to destination,
          alert: "Beyond Care presented a verification challenge. Nothing was submitted."
      else
        redirect_to destination,
          alert: "Beyond Care did not reach a submit-ready state. Nothing was submitted."
      end
    end
end
