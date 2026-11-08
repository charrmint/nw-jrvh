class YmcaConnectionsController < ApplicationController
  before_action :set_connection, only: %i[ update destroy ]

  def create
    @ymca_connection = Current.user.provider_connections.build(connection_params.merge(provider_key: "ymca"))
    if @ymca_connection.save
      redirect_to settings_path, notice: "YMCA account saved.", status: :see_other
    else
      render "settings/show", status: :unprocessable_content
    end
  end

  def update
    if @ymca_connection.update(connection_params)
      redirect_to settings_path, notice: "YMCA account updated.", status: :see_other
    else
      render "settings/show", status: :unprocessable_content
    end
  end

  def destroy
    @ymca_connection.destroy!
    redirect_to settings_path, notice: "YMCA account removed.", status: :see_other
  end

  private
    def set_connection
      @ymca_connection = Current.user.provider_connections.find_by!(provider_key: "ymca")
    end

    def connection_params
      params.require(:provider_connection).permit(:username, :password)
    end
end
