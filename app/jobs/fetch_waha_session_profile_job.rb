class FetchWahaSessionProfileJob < ApplicationJob
  queue_as :default

  def perform(waha_session_id)
    session = WahaSession.find_by(id: waha_session_id)
    return unless session&.working?

    me = session.waha_client.sessions.me
    return unless me.is_a?(Hash)

    updates = {}
    updates[:waha_chat_id]  = me["id"]          if me["id"].present?
    updates[:display_name]  = me["pushName"]     if me["pushName"].present?

    if updates.any?
      session.update!(updates)
    end

    # Fetch avatar
    if me["id"].present?
      avatar_data = session.waha_client.contacts.profile_picture(contact_id: me["id"])
      url = avatar_data.is_a?(Hash) ? avatar_data["profilePictureURL"] : nil
      session.update!(avatar_url: url) if url.present?
    end
  rescue => e
    Rails.logger.warn "[FetchWahaSessionProfileJob] #{e.message}"
  end
end
