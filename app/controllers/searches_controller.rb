class SearchesController < ApplicationController
  # Front end only: no results yet. Echoes the chosen filters so the layout can be reviewed.
  def show
    @children = DemoData::CHILDREN
    @searched = params[:commit].present?
  end
end
