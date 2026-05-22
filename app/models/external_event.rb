class ExternalEvent < ApplicationRecord
  enum :provider, {
    waha: "waha",
  }, default: :waha

  enum :status, { pending: "pending", completed: "completed", failed: "failed" }, default: :pending

  def process
    whatsapp_processor = ExternalEvents::WhatsappProcessor.new(self)
    case provider
    when "waha"
      whatsapp_processor.process_event(worker_type: :waha)
    else
      raise "Unknown provider: #{provider}"
    end
  end

  def enqueue_processing
    ExternalEventProcessingJob.perform_later(self.id)
  end
end
