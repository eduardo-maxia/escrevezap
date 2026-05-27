class TrackUsageJob < ApplicationJob
  queue_as :default

  def perform(user_id:, event_type:, metadata: {})
    user = User.find_by(id: user_id)
    return unless user

    UsageEvent.track(user: user, event_type: event_type, metadata: metadata)
  end
end
