class HomeController < ApplicationController
  def show
    @children = Current.user.children.order(:full_name)
    @applications = DaycareApplication.joins(:child).where(children: { user_id: Current.user.id })
      .includes(:child, :daycare).order(updated_at: :desc)
  end
end
