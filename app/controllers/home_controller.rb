class HomeController < ApplicationController
  def show
    @children = Current.user.children.order(:full_name)
    @applications = DemoData::APPLICATIONS # placeholder until applications are stored
  end
end
