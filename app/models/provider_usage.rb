class ProviderUsage < ApplicationRecord
  belongs_to :transcription

  DEEPGRAM_USD_PER_SECOND = 0.0059 / 60.0  # Nova-2: $0.0059/min
  OPENAI_USD_PER_TOKEN    = 5.0 / 1_000_000 # GPT-4o input: $5/1M tokens (approx average)

  scope :deepgram, -> { where(provider: "deepgram") }
  scope :openai,   -> { where(provider: "openai") }
  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..) }

  def self.total_cost_usd
    sum(:cost_usd)
  end
end
