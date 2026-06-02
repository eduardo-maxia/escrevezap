class MonitoredContact < ApplicationRecord
  belongs_to :waha_session
  has_many   :transcriptions
  has_one    :user, through: :waha_session

  default_scope { where(deleted_at: nil) }

  enum :direction, {
    incoming: "incoming",   # transcribe only their audios
    outgoing: "outgoing",   # transcribe only my audios sent to them
    both:     "both"        # transcribe all audios in this chat
  }, default: :both

  validates :phone_number, presence: true
  validates :phone_number, uniqueness: { scope: :waha_session_id, conditions: -> { where(deleted_at: nil) } }

  scope :enabled, -> { where(enabled: true) }
  scope :user_visible, -> { where(auto_created: false) }

  def soft_delete!
    update_column(:deleted_at, Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  # Derive waha_chat_id from phone_number if not already set.
  def resolve_waha_chat_id
    waha_chat_id.presence || "#{phone_number}@c.us"
  end

  def transcriptions_this_month
    transcriptions.where("created_at >= ?", Time.current.beginning_of_month)
  end

  def formatted_phone
    digits = phone_number.to_s.gsub(/\D/, "")
    if digits.start_with?("55") && digits.length.in?([12, 13])
      local = digits[2..]
      area  = local[0, 2]
      num   = local[2..]
      num.length == 9 ? "(#{area}) #{num[0, 5]}-#{num[5..]}" : "(#{area}) #{num[0, 4]}-#{num[4..]}"
    else
      phone_number.to_s
    end
  end
end
