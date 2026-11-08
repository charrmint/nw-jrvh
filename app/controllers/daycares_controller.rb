class DaycaresController < ApplicationController
  def index
    @daycares = Daycare.search(**search_params).alphabetical.limit(100)
  end

  def show
    @daycare = Daycare.find(params[:id])
  end

  private
    def search_params
      params.permit(:name, :city, :postal_code).to_h.symbolize_keys
    end
end
