class Client < ApplicationRecord
  include PgSearch::Model
  include WahaPhoneFormattable

  belongs_to :company

  has_one_attached :avatar
  has_many :campaign_clients, dependent: :destroy
  has_many :campaigns, through: :campaign_clients

  validates :name, presence: true

  pg_search_scope :search_by_term,
    against: { name: "A", email: "B", phone_number: "C" },
    using: {
      tsearch: { prefix: true }
    }

  before_save :fetch_waha_chat_id, if: -> { waha_chat_id.blank? && phone_number.present? }

  private

  def fetch_waha_chat_id
    chip = company.chips.find_by(provider: :waha)
    return unless chip

    result = Waha::Client.new(session: chip.waha_session)
                         .contacts.check_exists(phone: phone_number)
    self.waha_chat_id = result["chatId"] if result["numberExists"]
  rescue ApiRequest::ApiClientError, ApiRequest::ApiServerError,
         ApiRequest::ApiConnectionError
    # deixa waha_chat_id como nil
  end
end
