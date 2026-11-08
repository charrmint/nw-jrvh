class SettingsController < ApplicationController
  def show
    @ymca_connection = Current.user.provider_connections.find_by(provider_key: "ymca") || Current.user.provider_connections.build(provider_key: "ymca")
  end
end
