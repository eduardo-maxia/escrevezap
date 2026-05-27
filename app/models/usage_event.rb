class UsageEvent < ApplicationRecord
  belongs_to :user

  TRANSCRIPTION_COMPLETED = "transcription_completed"
  AI_FORMAT_COMPLETED     = "ai_format_completed"

  scope :this_month, -> { where(occurred_at: Time.current.beginning_of_month..) }
  scope :last_30_days, -> { where(occurred_at: 30.days.ago..) }

  def self.track(user:, event_type:, metadata: {})
    create!(user: user, event_type: event_type, metadata: metadata, occurred_at: Time.current)
  end
end
