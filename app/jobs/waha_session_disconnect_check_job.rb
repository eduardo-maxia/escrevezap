class WahaSessionDisconnectCheckJob < ApplicationJob
  queue_as :default

  def perform(waha_session_id)
    session = WahaSession.find_by(id: waha_session_id)
    return unless session
    return if session.working?

    # Session is still disconnected — notify the owner
    user = session.user
    Rails.logger.warn "[WahaSessionDisconnectCheckJob] Session #{waha_session_id} for user #{user.id} is disconnected (#{session.waha_status})"

    WahaSessionMailer.disconnected(user).deliver_later
  end
end
