class TranscriptionError < ApplicationRecord
  belongs_to :transcription

  STAGES = %w[
    download_audio
    attach_audio
    stt
    ai_format
    send_whatsapp
    track_usage
    process
  ].freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where("created_at >= ?", Time.current.beginning_of_month) }
  scope :by_stage, ->(stage) { where(stage: stage) }
end
