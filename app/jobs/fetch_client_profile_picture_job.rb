require "net/http"

class FetchClientProfilePictureJob < ApplicationJob
  queue_as :default

  def perform(client_id)
    client = Client.find_by(id: client_id)
    return unless client&.waha_chat_id.present?

    chip = client.company.chips.find_by(provider: :waha)
    return unless chip&.working?

    waha = Waha::Client.new(session: chip.waha_session)

    picture_data = waha.contacts.profile_picture(contact_id: client.waha_chat_id)
    url = picture_data.is_a?(Hash) ? picture_data["profilePictureURL"] : nil
    return if url.blank?

    image_bytes = Net::HTTP.get(URI.parse(url))
    return if image_bytes.blank?

    client.avatar.attach(
      io: StringIO.new(image_bytes),
      filename: "avatar.jpg",
      content_type: "image/jpeg"
    )
  rescue => e
    Rails.logger.warn("[FetchClientProfilePictureJob] client=#{client_id} #{e.class}: #{e.message}")
    Sentry.capture_exception(e)
  end
end
