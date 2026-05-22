class ExternalEventProcessingJob < ApplicationJob
  def perform(external_event_id)
    external_event = ExternalEvent.find(external_event_id)
    external_event.process
  end
end