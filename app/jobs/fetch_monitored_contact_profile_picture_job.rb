class FetchMonitoredContactProfilePictureJob < ApplicationJob
  queue_as :default

  def perform(monitored_contact_id)
    contact = MonitoredContact.find_by(id: monitored_contact_id)
    return unless contact

    waha_session = contact.waha_session
    return unless waha_session&.working?

    chat_id = contact.resolve_waha_chat_id

    picture_data = waha_session.waha_client.contacts.profile_picture(contact_id: chat_id)
    url = picture_data.is_a?(Hash) ? picture_data["profilePictureURL"] : nil
    return if url.blank?

    contact.update_column(:avatar_url, url)
  rescue => e
    Rails.logger.warn("[FetchMonitoredContactProfilePictureJob] contact=#{monitored_contact_id} #{e.class}: #{e.message}")
  end
end
