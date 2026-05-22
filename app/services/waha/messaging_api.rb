module Waha
  # Sends WhatsApp messages with a human-like flow:
  #   1. Marks all unread messages in the chat as read
  #   2. Starts the "typing…" indicator
  #   3. Sleeps for a duration proportional to the message length
  #   4. Stops the typing indicator
  #   5. Sends the message
  #
  # The typing duration mirrors the JS formula used by real clients:
  #   typingTime = clamp(textLength * 0.15, 2, 20) + rand(0..3) + 1   (seconds)
  #
  # Usage (always call from a background job — sleep blocks the thread):
  #   Waha::Client.new(session: "default")
  #     .messaging
  #     .send_message(chat_id: "5511999999999@c.us", text: "Olá!")
  class MessagingApi < Service
    # Full human-like send flow.
    # ⚠️  This method sleeps the current thread. Only call from background jobs.
    #
    # Returns the API response from POST /api/sendText.
    def send_message(chat_id:, text:, reply_to: nil)
      # 1. Mark all incoming messages as read (shows double blue tick to contact)
      @api_request.post("/api/#{@session}/chats/#{chat_id}/messages/read", {})

      # 2. Start typing indicator
      @api_request.post("/api/#{@session}/presence", {
        chatId:   chat_id,
        presence: "typing"
      })

      # 3. Wait — simulates realistic typing time based on message length
      sleep(typing_duration(text.length))

      # 4. Stop typing indicator
      @api_request.post("/api/#{@session}/presence", {
        chatId:   chat_id,
        presence: "paused"
      })

      # 5. Send the actual message
      send_text(chat_id: chat_id, text: text, reply_to: reply_to)
    end

    # Send a plain-text message without the human-like flow.
    #
    # POST /api/sendText
    def send_text(chat_id:, text:, reply_to: nil)
      body = { session: @session, chatId: chat_id, text: text }
      body[:reply_to] = reply_to if reply_to
      response = @api_request.post("/api/sendText", body)
      response = JSON.parse(response)
      response['id'] = response.dig('_data', 'Info', 'ID')
      response
    end

    # Mark a specific message (or all unread in the chat) as seen.
    # Prefer ChatsApi#read_messages for bulk marking.
    #
    # POST /api/sendSeen
    def send_seen(chat_id:)
      @api_request.post("/api/sendSeen", { session: @session, chatId: chat_id })
    end

    # Get a specific message by its ID.
    #
    # GET /api/getMessage
    def get_message(chat_id:, message_id:)
      response = @api_request.get("/api/#{@session}/chats/#{chat_id}/messages/#{message_id}?downloadMedia=true", { session: @session, messageId: message_id })
      JSON.parse(response)
    end

    def download_media_from_url(media_url:)
      # We have to just fetch whatever is media_url, but using our api_key
      api_request = ApiRequest.new(media_url, {
        "X-Api-Key" => Rails.application.credentials.dig(:waha, :api_key)
      })
      api_request.get("", {})
    end

    private

    # Mirrors the JS formula used by WhatsApp Web clients:
    #   const typingTime = Math.max(Math.min(textLength * 0.15, 20), 2) + Math.random() * 3 + 1;
    #
    # Range: minimum ~3 s (short messages), maximum ~24 s (very long messages).
    def typing_duration(text_length)
      return 3 if Rails.env.development?
      base = [[text_length * 0.15, 20].min, 2].max
      base + rand * 3 + 1
    end
  end
end
