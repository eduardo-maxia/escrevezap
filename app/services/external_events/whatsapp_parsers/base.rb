module ExternalEvents
  module WhatsappParsers
    class Base
      def initialize(raw_data)
        @raw_data = raw_data
      end

      def parse
        raise NotImplementedError, "Subclasses must implement the parse method"
      end

      protected

      # Helper to safely extract phone number from different formats
      def extract_phone_number(waha_chat_id)
        return nil unless waha_chat_id.present?
        waha_chat_id.split('@').first
      end

      # Helper to format timestamp to Rails Time object
      def parse_timestamp(timestamp)
        return Time.now if timestamp.nil?
        timestamp.is_a?(String) ? Time.at(Integer(timestamp)) : Time.at(timestamp)
      end
    end
  end
end
