# config/initializers/loggable.rb
module Loggable
  extend ActiveSupport::Concern

  included do
    private

    def log_debug(message, extra = {})
      Rails.logger.debug(format_message("debug", message, extra))
    end

    def log_info(message, extra = {})
      Rails.logger.info(format_message("info", message, extra))
    end

    def log_error(message, extra = {})
      Rails.logger.error(format_message("error", message, extra))
    end

    def log_warning(message, extra = {})
      Rails.logger.warn(format_message("warn", message, extra))
    end

    def format_message(level, message, extra = {})
      unless Rails.env.production?
        # Keep colors locally
        color = { "info" => 32, "error" => 31, "warn" => 33 }[level]
        "\e[#{color}m[#{self.class.name}] #{message}\e[0m"
      else
        # JSON output for Fly.io / Grafana
        {
          level: level,
          source: self.class.name,
          message: message,
          timestamp: Time.current.utc.iso8601
        }.merge(extra).to_json
      end
    end
  end

  class_methods do
    private

    def log_info(message, extra = {})
      Rails.logger.info(format_message("info", message, extra))
    end

    def log_error(message, extra = {})
      Rails.logger.error(format_message("error", message, extra))
    end

    def log_warning(message, extra = {})
      Rails.logger.warn(format_message("warn", message, extra))
    end

    def format_message(level, message, extra = {})
      if Rails.env.development?
        # Keep colors locally
        color = { "info" => 32, "error" => 31, "warn" => 33 }[level]
        "\e[#{color}m[#{self.name}] #{message}\e[0m"
      else
        # JSON output for Fly.io / Grafana
        {
          level: level,
          source: self.name,
          message: message,
          timestamp: Time.current.utc.iso8601
        }.merge(extra).to_json
      end
    end
  end
end
