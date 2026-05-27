class BillingEvent < ApplicationRecord
  validates :event_id, presence: true, uniqueness: true
  validates :event_type, presence: true

  scope :unprocessed, -> { where(processed: false) }
end
