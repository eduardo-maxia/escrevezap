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
  after_update_commit :schedule_disconnect_notification, if: :saved_change_to_waha_status?
  after_update_commit :fetch_profile_picture_on_first_connect, if: :saved_change_to_waha_status?

  private

  def broadcast_waha_status_change
    ActionCable.server.broadcast("chip_status_#{id}", { status: waha_status })
  end

  def schedule_disconnect_notification
    old_status, new_status = saved_change_to_waha_status
    return unless old_status == "working" && new_status != "working"

    ChipDisconnectCheckJob.set(wait: 1.minute).perform_later(id)
  end

  def fetch_profile_picture_on_first_connect
    _old_status, new_status = saved_change_to_waha_status
    return unless new_status == "working"
    return if company.profile_picture.attached?

    FetchChipProfilePictureJob.perform_later(id)
  end
end
