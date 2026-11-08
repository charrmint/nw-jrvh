class DaycareApplicationsController < ApplicationController
  def index
    @applications = owned_applications.order(updated_at: :desc)
  end

  def show
    @application = owned_applications.find(params[:id])
  end

  private
    def owned_applications
      DaycareApplication.joins(:child).where(children: { user_id: Current.user.id }).includes(:child, :daycare)
    end
end
