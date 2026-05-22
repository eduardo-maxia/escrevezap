class DailyBillingJob < ApplicationJob
  queue_as :default

  def perform
    today = Date.today
    log_info "[DailyBillingJob] Starting daily billing process for #{today}"

    Installment
      .pending
      .where(due_date: today)
      .joins(:campaign_client)
      .where(campaign_clients: { status: :active })
      .includes(campaign_client: [:campaign, :client])
      .each { |installment| process_installment(installment) }
  end

  private

  # Idempotency guard (Rule 3):
  # Allow creating a new notification only when every existing one for this
  # installment today is in the :failed or :cancelled state (so a retry is legitimate).
  def can_notify?(installment)
    existing = Notification
                 .where(installment: installment)
                 .where(scheduled_at: Date.today.all_day)
                 .where.not(notification_status: [:failed, :cancelled])
    !existing.exists?
  end

  def process_installment(installment)
    return unless can_notify?(installment)

    campaign_client = installment.campaign_client
    campaign        = campaign_client.campaign
    chip            = campaign.chip

    # Skip if the WhatsApp chip is not configured
    unless chip&.waha_session.present?
      Rails.logger.warn "[DailyBillingJob] installment=#{installment.id} skipped — chip not configured"
      return
    end

    scheduled_at = random_time_in_window(campaign)
    payload      = campaign_client.build_notification_payload(installment)

    notification = Notification.create!(
      campaign_client:     campaign_client,
      installment:         installment,
      sender:              chip,
      event_type:          :message,
      notification_status: :pending,
      scheduled_at:        scheduled_at,
      payload:             payload
    )

    SendMessageJob.set(wait_until: scheduled_at).perform_later(notification.id)

    # Advance the installment cycle: create next month's installment and
    # update next_due_date on the campaign_client (bypasses model callbacks).
    advance_cycle(campaign_client, installment)

  rescue => e
    Rails.logger.error "[DailyBillingJob] installment=#{installment.id} error=#{e.class}: #{e.message}"
  end

  # Computes a random Time within the campaign's operating window for today.
  def random_time_in_window(campaign)
    start_h, start_m = campaign.start_time.to_s.split(' ')[1].split(":").map(&:to_i)
    end_h,   end_m   = campaign.end_time.to_s.split(' ')[1].split(":").map(&:to_i)

    start_secs = start_h * 3600 + start_m * 60
    end_secs   = end_h   * 3600 + end_m   * 60

    Date.today.in_time_zone.beginning_of_day + rand(start_secs..end_secs).seconds
  end

  def advance_cycle(campaign_client, current_installment)
    next_due    = current_installment.due_date >> 1   # +1 month; Rails handles end-of-month
    month_start = next_due.beginning_of_month
    month_end   = next_due.end_of_month

    # Skip if a non-cancelled installment for next month already exists (idempotency).
    exists = campaign_client.installments
                            .where.not(status: :cancelled)
                            .where(due_date: month_start..month_end)
                            .exists?

    unless exists
      campaign_client.installments.create!(
        due_date: next_due,
        amount:   campaign_client.amount,
        status:   :pending
      )
    end

    # update_columns bypasses model callbacks, preventing a sync_future_installments loop.
    campaign_client.update_columns(next_due_date: next_due)
  end
end
