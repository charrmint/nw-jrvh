class DaycareApplicationsController < ApplicationController
  def index
    @applications = DemoData::APPLICATIONS
    @open = DemoData.application(params[:open])
  end

  def show
    @application = DemoData.application(params[:id]) || (raise ActionController::RoutingError, "Not Found")
  end
end
