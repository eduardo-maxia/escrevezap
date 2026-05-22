require "net/http"

class FetchChipProfilePictureJob < ApplicationJob
  queue_as :default

  def perform(chip_id)
    chip = Chip.find_by(id: chip_id)
    return unless chip&.working?
    return if chip.company.profile_picture.attached?

    waha = Waha::Client.new(session: chip.waha_session)

    # Get the chip's own WhatsApp contact ID
    me_data = waha.sessions.me
    return unless me_data.is_a?(Hash) && me_data["id"].present?

    # Fetch the profile picture URL
    picture_data = waha.contacts.profile_picture(contact_id: me_data["id"])
    url = picture_data.is_a?(Hash) ? picture_data["profilePictureURL"] : nil
    return if url.blank?

    # Download the image and attach it to the company
    image_bytes = Net::HTTP.get(URI.parse(url))
    return if image_bytes.blank?

    chip.company.profile_picture.attach(
      io: StringIO.new(image_bytes),
      filename: "profile_picture.jpg",
      content_type: "image/jpeg"
    )
  rescue => e
    Rails.logger.warn("[FetchChipProfilePictureJob] chip=#{chip_id} #{e.class}: #{e.message}")
  end
end
