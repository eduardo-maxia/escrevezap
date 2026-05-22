module WahaPhoneFormattable
  extend ActiveSupport::Concern

  # Returns a human-readable BR phone number derived from waha_chat_id.
  # e.g. waha_chat_id "5521936181803@c.us" → "(21) 93618-1803"
  # Returns nil if waha_chat_id is blank.
  def formatted_number
    return nil unless waha_chat_id.present?

    raw = waha_chat_id.split("@").first  # "5521936181803"
    area_code = raw[2..3]               # "21"
    number    = raw[4..]                # "936181803"

    local = if number.length == 9
              "#{number[0]}#{number[1..4]}-#{number[5..8]}"
            else
              "#{number[0..3]}-#{number[4..7]}"
            end

    "(#{area_code}) #{local}"
  end
end
