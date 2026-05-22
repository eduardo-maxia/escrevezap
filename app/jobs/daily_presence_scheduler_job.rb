class DailyPresenceSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    today_start = Date.today.in_time_zone.beginning_of_day

    # Collect the earliest start_time and latest end_time per chip across all
    # campaigns that have a working chip and a configured time window.
    chip_windows = {}

    Campaign
      .joins(:chip)
      .where(chips: { waha_status: "working" })
      .where.not(start_time: nil)
      .where.not(end_time: nil)
      .each do |campaign|
        id      = campaign.chip_id
        s_secs  = campaign.start_time.seconds_since_midnight.to_i
        e_secs  = campaign.end_time.seconds_since_midnight.to_i

        if chip_windows.key?(id)
          chip_windows[id][:online]  = [chip_windows[id][:online],  s_secs].min
          chip_windows[id][:offline] = [chip_windows[id][:offline], e_secs].max
        else
          chip_windows[id] = { online: s_secs, offline: e_secs }
        end
      end

    now = Time.current

    chip_windows.each do |chip_id, window|
      online_at  = today_start + window[:online].seconds
      offline_at = today_start + window[:offline].seconds

      # Only schedule if the target time is still in the future
      if online_at > now
        SetChipPresenceJob.set(wait_until: online_at).perform_later(chip_id, "online")
      else
        Rails.logger.info "[DailyPresenceSchedulerJob] chip=#{chip_id} online window already passed (#{online_at}), skipping"
      end

      if offline_at > now
        SetChipPresenceJob.set(wait_until: offline_at).perform_later(chip_id, "offline")
      else
        Rails.logger.info "[DailyPresenceSchedulerJob] chip=#{chip_id} offline window already passed (#{offline_at}), skipping"
      end
    end
  end
end
