class FetchMonitoredContactProfilePictureJob < ApplicationJob
  queue_as :default

  def perform(monitored_contact_id)
    contact = MonitoredContact.find_by(id: monitored_contact_id)
    return unless contact

    waha_session = contact.waha_session
    return unless waha_session&.working?

    chat_id = contact.resolve_waha_chat_id

    fetch_avatar(contact, waha_session, chat_id)
    fetch_display_name(contact, waha_session, chat_id) if contact.display_name.blank?
  rescue => e
    Rails.logger.warn("[FetchMonitoredContactProfilePictureJob] contact=#{monitored_contact_id} #{e.class}: #{e.message}")
  end

  private

  def fetch_avatar(contact, waha_session, chat_id)
    picture_data = waha_session.waha_client.contacts.profile_picture(contact_id: chat_id)
    url = picture_data.is_a?(Hash) ? picture_data["profilePictureURL"] : nil
    contact.update_column(:avatar_url, url) if url.present?
  rescue => e
    Rails.logger.warn("[FetchMonitoredContactProfilePictureJob] avatar fetch failed for contact=#{contact.id}: #{e.message}")
  end

  def fetch_display_name(contact, waha_session, chat_id)
    all_contacts = waha_session.waha_client.contacts.list_all
    match = all_contacts.find { |c| c["id"] == chat_id }
    return unless match

    name = match["name"].presence || match["pushname"].presence
    contact.update_column(:display_name, name) if name.present?
  rescue => e
    Rails.logger.warn("[FetchMonitoredContactProfilePictureJob] display_name fetch failed for contact=#{contact.id}: #{e.message}")
  end
end
