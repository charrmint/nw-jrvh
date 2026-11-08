class YmcaExperimentsController < ApplicationController
  def create
    daycare = Daycare.find(params[:daycare_id])
    child = Current.user.children.includes(:general_application).find(params.require(:child_id))

    result = Automation::Ymca::ExperimentRunner.new(child:, daycare:).call
    redirect_to daycare_path(daycare, child_id: child.id), notice: success_message(result)
  rescue Automation::Ymca::ExperimentRunner::Error => error
    redirect_to daycare_path(params[:daycare_id], child_id: params[:child_id]), alert: error.message
  end

  private
    def success_message(result)
      child_action = result["child_profile_action"] == "reused_existing" ? "Existing YMCA child reused." :
        "YMCA child details prepared."
      "YMCA application reached Review without submitting. #{child_action}"
    end
end
