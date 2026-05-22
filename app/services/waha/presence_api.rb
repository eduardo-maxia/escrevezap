module Waha
  # Manages WhatsApp presence (online/offline/typing/recording) for a session.
  #
  # Usage:
  #   client = Waha::Client.new(session: "default")
  #   client.presence.set_online
  #   client.presence.start_typing(chat_id: "5511999999999@c.us")
  #   client.presence.stop_typing(chat_id: "5511999999999@c.us")
  #   client.presence.all
  #   client.presence.for_chat(chat_id: "5511999999999@c.us")
  #   client.presence.subscribe(chat_id: "5511999999999@c.us")
  class PresenceApi < Service
    # Mark session as globally online (all contacts will see it).
    #
    # POST /api/{session}/presence
    def set_online
      set(presence: "online")
    end

    # Mark session as offline. Required after sending presence to ensure
    # the phone still receives push notifications (WhatsApp suppresses them
    # while a web client is active).
    #
    # POST /api/{session}/presence
    def set_offline
      set(presence: "offline")
    end

    # Start showing "typing…" in the given chat.
    #
    # POST /api/{session}/presence
    def start_typing(chat_id:)
      set(presence: "typing", chat_id: chat_id)
    end

    # Stop the typing indicator (resets to paused).
    #
    # POST /api/{session}/presence
    def stop_typing(chat_id:)
      set(presence: "paused", chat_id: chat_id)
    end

    # Show "recording audio…" in the given chat.
    #
    # POST /api/{session}/presence
    def start_recording(chat_id:)
      set(presence: "recording", chat_id: chat_id)
    end

    # Generic presence setter.
    # presence: "online" | "offline" | "typing" | "recording" | "paused"
    # chat_id is required for chat-level presences (typing, recording, paused).
    #
    # POST /api/{session}/presence
    def set(presence:, chat_id: nil)
      body = { presence: presence }
      body[:chatId] = chat_id if chat_id
      @api_request.post("/api/#{@session}/presence", body)
    end

    # Get presence info for all chats.
    # Returns array of { id, presences: [{ participant, lastKnownPresence, lastSeen }] }
    #
    # GET /api/{session}/presence
    def all
      @api_request.get("/api/#{@session}/presence")
    end

    # Get presence info for a single chat (or group participants).
    # Returns { id, presences: [...] }
    #
    # GET /api/{session}/presence/{chatId}
    def for_chat(chat_id:)
      @api_request.get("/api/#{@session}/presence/#{chat_id}")
    end

    # Subscribe to receive presence updates for a chat via the presence.update webhook.
    # After subscribing, poll with `for_chat` or listen to the webhook.
    #
    # POST /api/{session}/presence/{chatId}/subscribe
    def subscribe(chat_id:)
      @api_request.post("/api/#{@session}/presence/#{chat_id}/subscribe")
    end
  end
end
