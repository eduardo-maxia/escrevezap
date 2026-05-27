class WahaSessionEvent < ApplicationRecord
  belongs_to :waha_session

  scope :recent, -> { order(occurred_at: :desc).limit(50) }
end
