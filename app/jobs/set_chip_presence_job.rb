class SetChipPresenceJob < ApplicationJob
  queue_as :default

  # status: "online" | "offline"
  def perform(chip_id, status)
    chip = Chip.find_by(id: chip_id)

    # Skip if chip was deleted or is no longer connected
    return unless chip&.waha_status == "working"

    waha = Waha::Client.new(session: chip.waha_session)

    case status
    when "online"  then waha.presence.set_online
    when "offline" then waha.presence.set_offline
    else
      Rails.logger.warn "[SetChipPresenceJob] Unknown status '#{status}' for chip=#{chip_id}"
    end

  rescue ApiRequest::ApiClientError, ApiRequest::ApiServerError,
         ApiRequest::ApiConnectionError => e
    Rails.logger.warn "[SetChipPresenceJob] chip=#{chip_id} status=#{status} error=#{e.message}"
  end
end
