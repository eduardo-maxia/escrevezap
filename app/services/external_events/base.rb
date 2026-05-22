class ExternalEvents::Base
  include Loggable
  
  class ScheduleRetryError < StandardError; end

  def initialize(external_event)
    @external_event = external_event
    @data = external_event.data.deep_symbolize_keys
  end

  def process(**kwargs)
    raise NotImplementedError, "Subclasses must implement the process method"
  end

  def process_event(**kwargs)
    ActiveRecord::Base.transaction do
      process(**kwargs)
      @external_event.update!(status: :completed, error_message: nil, retry_count: 0)
    end
  rescue ScheduleRetryError => e
    retry_count = @external_event.retry_count || 0
    
    if retry_count < 5
      delay = 5 * (2 ** retry_count) # 5s, 10s, 20s, 40s, 80s
      @external_event.update!(retry_count: retry_count + 1, error_message: e.message)
      
      log_info "Agendando nova tentativa (#{retry_count + 1}/5) para o evento #{@external_event.id} em #{delay}s devido a: #{e.message}"
      
      ExternalEventProcessingJob.set(wait: delay.seconds).perform_later(@external_event.id)
    else
      @external_event.update!(status: :failed, error_message: "Máximo de tentativas (5) atingido: #{e.message}")
      log_error "Máximo de tentativas atingido para o evento #{@external_event.id}: #{e.message}"
    end
  rescue StandardError => e
    @external_event.update!(status: :failed, error_message: e.message)
    raise e
  end
end