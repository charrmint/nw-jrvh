class GmailConnectionsController < ApplicationController
  def new
    state = SecureRandom.urlsafe_base64(32)
    session[:gmail_oauth_state] = state
    redirect_to Gmail::OauthClient.new.authorization_url(state: state), allow_other_host: true
  rescue Gmail::OauthClient::Error => error
    redirect_to settings_path, alert: error.message
  end

  def create
    expected_state = session.delete(:gmail_oauth_state).to_s
    unless valid_state?(expected_state, params[:state].to_s)
      return redirect_to(settings_path, alert: "Gmail connection could not be verified. Please try again.")
    end
    if params[:error].present?
      return redirect_to(settings_path, alert: "Gmail was not connected: #{params[:error]}.")
    end

    tokens = Gmail::OauthClient.new.exchange_code(params.require(:code))
    connection = Current.user.mailbox_connection || Current.user.build_mailbox_connection
    connection.assign_attributes(
      access_token: tokens.fetch("access_token"),
      refresh_token: tokens.fetch("refresh_token"),
      access_token_expires_at: tokens.fetch("expires_in", 3600).to_i.seconds.from_now,
      scope: MailboxConnection::GMAIL_SEND_SCOPE,
      connected_at: Time.current
    )
    connection.save!
    redirect_to settings_path, notice: "Gmail connected. OneKare can send email but cannot read your inbox."
  rescue ActionController::ParameterMissing, Gmail::OauthClient::Error => error
    redirect_to settings_path, alert: error.message
  end

  def destroy
    connection = Current.user.mailbox_connection
    if connection
      Gmail::OauthClient.new.revoke(connection.refresh_token)
      connection.destroy!
    end
    redirect_to settings_path, notice: "Gmail disconnected from OneKare."
  end

  private
    def valid_state?(expected, actual)
      expected.present? && actual.present? && expected.bytesize == actual.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end
end
