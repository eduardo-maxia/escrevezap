class WahaSessionStatusChannel < ApplicationCable::Channel
  def subscribed
    stream_from "waha_session_status_user_#{current_user.id}"
  end

  def unsubscribed
    stop_all_streams
  end
end
