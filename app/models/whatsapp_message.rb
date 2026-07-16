class WhatsappMessage < ApplicationRecord
  belongs_to :user, optional: true

  enum :direction, {
    incoming: "incoming",
    outgoing: "outgoing"
  }, default: :incoming

  enum :message_type, {
    text: "text",
    interactive: "interactive",
    template: "template",
    media: "media",
    contact: "contact",
    system: "system"
  }, default: :text

  validates :phone, :from, :to, :body, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :chronological, -> { order(created_at: :asc) }
end