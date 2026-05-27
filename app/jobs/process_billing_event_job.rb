class ProcessBillingEventJob < ApplicationJob
  queue_as :default

  def perform(billing_event_id)
    event = BillingEvent.find(billing_event_id)
    return if event.processed?

    Billing::EventHandler.new(event).process!

    event.update!(processed: true, processed_at: Time.current)
  rescue => e
    Rails.logger.error "[ProcessBillingEventJob] Error processing event #{billing_event_id}: #{e.message}"
    raise e
  end
end
