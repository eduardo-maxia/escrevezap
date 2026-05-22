class Chip < ApplicationRecord
  include WahaPhoneFormattable

  belongs_to :company

  validates :name, presence: true

  has_many :campaigns, dependent: :nullify
  has_many :notifications, as: :sender, dependent: :nullify

  enum :provider, { waha: "waha" }

  enum :waha_status, {
    pending: "pending", # Esse não eh um status do WAHA, só significa que a sessão não foi criada ainda
    stopped: "stopped",
    starting: "starting",
    scan_qr_code: "scan_qr_code",
    working: "working",
    failed: "failed"
  }, default: :starting

  after_update_commit :broadcast_waha_status_change, if: :saved_change_to_waha_status?

  private

  def broadcast_waha_status_change
    ActionCable.server.broadcast("chip_status_#{id}", { status: waha_status })
  end
end
