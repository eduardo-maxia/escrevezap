class WahaSession < ApplicationRecord
  belongs_to :user
  has_many :monitored_contacts, dependent: :destroy
  has_many :transcriptions, through: :monitored_contacts
  has_many :waha_session_events, dependent: :destroy

  enum :waha_status, {
    pending:      "pending",      # session not yet created in Waha
    stopped:      "stopped",
    starting:     "starting",
    scan_qr_code: "scan_qr_code",
    working:      "working",
    failed:       "failed"
  }, default: :pending

  validates :session_name, presence: true, uniqueness: true
  before_validation :set_session_name, on: :create

  after_update_commit :broadcast_status_change,        if: :saved_change_to_waha_status?
  after_update_commit :schedule_disconnect_check,      if: :saved_change_to_waha_status?
  after_update_commit :fetch_profile_picture,          if: :saved_change_to_waha_status?
  after_update_commit :complete_user_onboarding,       if: :saved_change_to_waha_status?
  after_update_commit :record_status_event,            if: :saved_change_to_waha_status?

  # Convenience shortcut for building API calls
  def waha_client
    Waha::Client.new(session: session_name)
  end

  # Create (or restart) the Waha session and mark as starting.
  def connect!
    waha_client.sessions.create
    update!(waha_status: :starting)
  rescue => e
    update!(waha_status: :failed)
    raise e
  end

  # Stop the Waha session gracefully.
  def disconnect!
    waha_client.sessions.stop
    update!(waha_status: :stopped)
  rescue => e
    Rails.logger.warn "[WahaSession#disconnect!] #{e.message}"
  end

  # Number of transcriptions processed this calendar month (excludes failed).
  def monthly_transcription_count
    transcriptions.where("transcriptions.created_at >= ?", Time.current.beginning_of_month)
                  .where.not(status: :failed)
                  .count
  end

  private

  def set_session_name
    self.session_name ||= "user_#{user_id}"
  end

  def broadcast_status_change
    ActionCable.server.broadcast("waha_session_status_user_#{user_id}", { status: waha_status })
  end

  def schedule_disconnect_check
    old_status, new_status = saved_change_to_waha_status
    return unless old_status == "working" && new_status != "working"

    WahaSessionDisconnectCheckJob.set(wait: 1.minute).perform_later(id)
  end

  def fetch_profile_picture
    _old, new_status = saved_change_to_waha_status
    return unless new_status == "working"
    return if display_name.present?

    FetchWahaSessionProfileJob.perform_later(id)
  end

  def complete_user_onboarding
    _old, new_status = saved_change_to_waha_status
    return unless new_status == "working"
    return if user.onboarding_completed?

    user.complete_onboarding!
  end

  def record_status_event
    old_status, new_status = saved_change_to_waha_status
    WahaSessionEvent.create!(
      waha_session: self,
      from_status:  old_status,
      to_status:    new_status,
      occurred_at:  Time.current
    )
  end
end
