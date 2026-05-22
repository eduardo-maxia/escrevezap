module Waha
  # Single entry point for the Waha SDK.
  # Lazily instantiates each API module and shares the session name across all of them.
  #
  # Examples:
  #
  #   # Default session
  #   client = Waha::Client.new
  #
  #   # Named session (e.g. one per company chip)
  #   client = Waha::Client.new(session: "company_42")
  #
  #   # Session lifecycle
  #   client.sessions.create
  #   client.sessions.qr               # => { "mimetype" => ..., "data" => "base64..." }
  #   client.sessions.me                # => { "id" => "55119...@c.us", "pushName" => "..." }
  #   client.sessions.restart
  #   client.sessions.destroy
  #
  #   # Contacts
  #   result = client.contacts.check_exists(phone: "5511999999999")
  #   chat_id = result["chatId"]
  #   client.contacts.profile_picture(contact_id: chat_id)
  #   client.contacts.lid_to_phone(lid: "123456@lid")
  #
  #   # Presence
  #   client.presence.subscribe(chat_id: chat_id)
  #   client.presence.for_chat(chat_id: chat_id)
  #
  #   # Chats
  #   client.chats.messages(chat_id: chat_id, limit: 30)
  #   client.chats.read_messages(chat_id: chat_id)
  #
  #   # Messaging (call from background job only — involves sleep)
  #   client.messaging.send_message(chat_id: chat_id, text: "Olá! 👋")
  class Client
    attr_reader :session

    def initialize(session: Service::DEFAULT_SESSION)
      @session = session
    end

    def sessions
      @sessions ||= SessionsApi.new(session: @session)
    end

    def presence
      @presence ||= PresenceApi.new(session: @session)
    end

    def contacts
      @contacts ||= ContactsApi.new(session: @session)
    end

    def chats
      @chats ||= ChatsApi.new(session: @session)
    end

    def messaging
      @messaging ||= MessagingApi.new(session: @session)
    end
  end
end
