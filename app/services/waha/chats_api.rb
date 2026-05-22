module Waha
  # Read and fetch messages from WhatsApp chats.
  #
  # Usage:
  #   client = Waha::Client.new(session: "default")
  #
  #   # Mark all unread messages in a chat as read (double blue tick)
  #   client.chats.read_messages(chat_id: "5511999999999@c.us")
  #
  #   # Fetch last 20 messages
  #   client.chats.messages(chat_id: "5511999999999@c.us", limit: 20)
  #
  #   # Fetch messages from a specific timestamp, excluding own messages
  #   client.chats.messages(chat_id: "...", limit: 50, from_me: false, timestamp_gte: 1_700_000_000)
  class ChatsApi < Service
    # Mark all unread messages in a chat as read (shows double blue checkmark).
    # Optionally limit how many messages and how many days back to mark.
    #
    # POST /api/{session}/chats/{chatId}/messages/read
    #
    # Returns: { "ids" => ["false_...@c.us_AAA", ...] }
    def read_messages(chat_id:, messages: nil, days: nil)
      body = {}
      body[:messages] = messages if messages
      body[:days]     = days     if days
      @api_request.post("/api/#{@session}/chats/#{chat_id}/messages/read", body)
    end

    # Fetch messages from a chat.
    #
    # GET /api/{session}/chats/{chatId}/messages
    #
    # Options:
    #   limit          – max messages to return (default: 20)
    #   offset         – pagination offset (default: 0)
    #   download_media – whether to include media attachments (default: false)
    #   from_me        – true = only mine, false = only theirs, nil = all
    #   timestamp_gte  – filter messages newer than this Unix timestamp
    #   timestamp_lte  – filter messages older than this Unix timestamp
    #
    # Returns array of message objects.
    def messages(chat_id:, limit: 20, offset: 0, download_media: false,
                 from_me: nil, timestamp_gte: nil, timestamp_lte: nil)
      params = { limit: limit, offset: offset, downloadMedia: download_media }
      params["filter.fromMe"]          = from_me       unless from_me.nil?
      params["filter.timestamp.gte"]   = timestamp_gte if timestamp_gte
      params["filter.timestamp.lte"]   = timestamp_lte if timestamp_lte
      @api_request.get("/api/#{@session}/chats/#{chat_id}/messages", params)
    end
  end
end
