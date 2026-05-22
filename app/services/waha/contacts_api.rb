module Waha
  # Contact lookup and LID↔phone mapping via the WAHA Contacts API.
  #
  # Usage:
  #   client = Waha::Client.new(session: "default")
  #
  #   # Check if a number is on WhatsApp (returns correct chatId for BR numbers)
  #   client.contacts.check_exists(phone: "5511999999999")
  #   # => { "numberExists" => true, "chatId" => "5511999999999@c.us" }
  #
  #   # Get profile picture URL
  #   client.contacts.profile_picture(contact_id: "5511999999999@c.us")
  #   # => { "profilePictureURL" => "https://..." }
  #
  #   # Convert @lid to @c.us
  #   client.contacts.lid_to_phone(lid: "123456789@lid")
  #   # => { "lid" => "...", "pn" => "5511999999999@c.us" }
  class ContactsApi < Service
    # Check whether a phone number has a WhatsApp account.
    # Always call this before messaging a new number — especially for 🇧🇷 Brazilian
    # numbers, as the returned `chatId` may differ from the raw phone number.
    #
    # GET /api/contacts/check-exists?phone={phone}&session={session}
    #
    # Returns: { "numberExists" => true/false, "chatId" => "...@c.us" }
    def check_exists(phone:)
      response = @api_request.get("/api/contacts/check-exists", { phone: phone, session: @session })
      JSON.parse(response)
    end

    # Fetch the profile picture URL for a contact.
    # Set `refresh: true` to bypass the 24h cache (use sparingly to avoid rate limits).
    #
    # GET /api/contacts/profile-picture?contactId={id}&session={session}
    #
    # Returns: { "profilePictureURL" => "https://..." }  (URL can be nil if no picture)
    def profile_picture(contact_id:, refresh: false)
      params = { contactId: contact_id, session: @session }
      params[:refresh] = true if refresh
      JSON.parse(@api_request.get("/api/contacts/profile-picture", params))
    end

    # Resolve a LID (@lid) to a phone number (@c.us).
    # WhatsApp uses LIDs to hide phone numbers in large groups.
    #
    # GET /api/{session}/lids/{lid}
    #
    # Returns: { "lid" => "...@lid", "pn" => "...@c.us" }
    def lid_to_phone(lid:)
      JSON.parse(@api_request.get("/api/#{@session}/lids/#{escape(lid)}"))
    end

    # Resolve a phone number (@c.us) to its LID (@lid).
    #
    # GET /api/{session}/lids/pn/{phoneNumber}
    #
    # Returns: { "lid" => "...@lid", "pn" => "...@c.us" }
    def phone_to_lid(phone:)
      JSON.parse(@api_request.get("/api/#{@session}/lids/pn/#{escape(phone)}"))
    end

    private

    # @ must be percent-encoded in path segments.
    def escape(value)
      value.to_s.gsub("@", "%40")
    end
  end
end
