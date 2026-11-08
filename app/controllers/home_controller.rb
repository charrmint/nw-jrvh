class HomeController < ApplicationController
  def show
    @children = DemoData::CHILDREN
    @applications = DemoData::APPLICATIONS
  end
end
