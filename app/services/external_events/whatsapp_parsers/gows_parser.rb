require 'time'

module ExternalEvents
  module WhatsappParsers
    # Parser for GOWS webhook payloads
    # Transforms GOWS webhook format into standardized format
    class GowsParser < Base
      def parse
        {
          event: determine_event_type,
          session: @raw_data[:session],
          worker: @raw_data[:worker],
          payload: build_payload
        }
      end

      private

      def determine_event_type
        @raw_data[:event]
      end

      def build_payload
        case @raw_data[:event]
        when 'session.status'
          build_session_status_payload
        when 'message.ack'
          build_message_ack_payload
        when 'message.reaction'
          build_message_reaction_payload
        when 'message'
          build_message_payload
        when 'message.any'
          build_message_payload
        else
          {}
        end
      end

      # Session status payload
      # Input: { session: "session_id", event: "session.status", payload: { status: "WORKING" }, me: { id: "..." } }
      # Output: { status: "working", waha_chat_id: "..." }
      def build_session_status_payload
        {
          status: @raw_data.dig(:payload, :status)&.downcase,
          waha_chat_id: @raw_data.dig(:me, :id)
        }
      end

      # Message ACK payload
      # Input: { event: "message.ack", payload: { id: "true_5521..._ABC123", ack: 2, _data: { Timestamp: "2026-01-17T16:48:40Z" } } }
      # Output: { message_id: "ABC123", ack: 2, created_at: Time }
      def build_message_ack_payload
        full_id = @raw_data.dig(:payload, :id)
        message_id = full_id.present? ? full_id.split('_').last : nil

        # Se o from for @lid, já transforma logo
        from = @raw_data.dig(:payload, :from)
        if from.present? && from.end_with?('@lid')
          response = Waha::ContactsApi.new(session: @raw_data[:session]).lid_to_phone(lid: from)
          
          from = response["pn"] if response["pn"].present?
        end

        {
          message_id: message_id,
          ack: @raw_data.dig(:payload, :ack),
          fromMe: @raw_data.dig(:payload, :fromMe),
          from: from,
          created_at: parse_gows_timestamp(@raw_data.dig(:payload, :_data, :Timestamp)) ||
            parse_gows_timestamp(@raw_data[:timestamp])
        }
      end

      # Message payload
      # Input: GOWS message webhook
      # Output: Standardized message format
      def build_message_payload
        payload = @raw_data[:payload]
        full_id = payload[:id]
        message_id = full_id.present? ? full_id.split('_').last : nil

        # Se o from for @lid, já transforma logo
        from = @raw_data.dig(:payload, :from)
        if from.present? && from.end_with?('@lid')
          response = Waha::ContactsApi.new(session: @raw_data[:session]).lid_to_phone(lid: from)
          
          from = response["pn"] if response["pn"].present?
        end

        contact_number = extract_contact_number(payload)
        contact_body = contact_number.present? ? "Usuário mandou um contato: #{contact_number}" : nil

        base_payload = {
          from: from,
          remoteJidAlt: payload.dig(:_data, :Info, :SenderAlt) || payload.dig(:_data, :Info, :RecipientAlt),
          fromMe: payload[:fromMe],
          message_id: message_id,
          created_at: payload[:timestamp].present? ? parse_timestamp(payload[:timestamp]) :
            parse_gows_timestamp(payload.dig(:_data, :Info, :Timestamp)),
          body: contact_body || payload[:body] || payload.dig(:_data, :Info, :Message, :conversation) ||
            payload.dig(:_data, :RawMessage, :conversation),
          hasMedia: payload[:hasMedia] || payload[:media].present?
        }

        # Add media information if present
        if base_payload[:hasMedia] && payload[:media].present?
          base_payload[:media] = {
            url: payload[:media][:url],
            mimetype: payload[:media][:mimetype],
            filename: payload[:media][:filename]
          }
        end

        if payload[:replyTo].present?
          base_payload[:reply_to] = {
            message_id: payload[:replyTo][:id]&.split('_').last,
            body: payload[:replyTo][:body]
          }
        end

        base_payload
      end

      # Message reaction payload
      # Input: GOWS message webhook
      # Output: Standardized message format
      def build_message_reaction_payload
        payload = @raw_data[:payload]
        full_id = payload[:id]
        message_id = full_id.present? ? full_id.split('_').last : nil

        contact_number = extract_contact_number(payload)
        contact_body = contact_number.present? ? "Usuário mandou um contato: #{contact_number}" : nil

        # Se o from for @lid, já transforma logo
        from = @raw_data.dig(:payload, :from)
        if from.present? && from.end_with?('@lid')
          response = Waha::ContactsApi.new(session: @raw_data[:session]).lid_to_phone(lid: from)
          
          from = response["pn"] if response["pn"].present?
        end

        base_payload = {
          from: from,
          remoteJidAlt: payload.dig(:_data, :Info, :SenderAlt) || payload.dig(:_data, :Info, :RecipientAlt),
          fromMe: payload[:fromMe],
          message_id: message_id,
          created_at: payload[:timestamp].present? ? parse_timestamp(payload[:timestamp]) :
            parse_gows_timestamp(payload.dig(:_data, :Info, :Timestamp)),
          body: payload.dig(:reaction, :text),
          reply_to_id: payload.dig(:reaction, :messageId)&.split('_')&.last,
        }

        base_payload
      end

      def extract_contact_number(payload)
        vcard = payload.dig(:_data, :Message, :contactMessage, :vcard) ||
          payload.dig(:_data, :RawMessage, :contactMessage, :vcard) ||
          payload[:vCards]&.first

        return nil if vcard.blank?

        waid_match = vcard.match(/waid=(\d+)/)
        return waid_match[1] if waid_match

        tel_match = vcard.match(/TEL[^:]*:(\+?\d+)/)
        tel_match ? tel_match[1] : nil
      end

      def parse_gows_timestamp(timestamp)
        return Time.now if timestamp.nil?

        if timestamp.is_a?(String)
          return Time.parse(timestamp) if timestamp.match?(/[A-Za-z]/) || timestamp.include?('-')
          return Time.at(Integer(timestamp))
        end

        if timestamp.is_a?(Numeric)
          return Time.at(timestamp / 1000.0) if timestamp > 10_000_000_000
          return Time.at(timestamp)
        end

        Time.now
      rescue StandardError
        Time.now
      end
    end
  end
end
