class Transcription < ApplicationRecord
  belongs_to :monitored_contact
  has_one    :waha_session, through: :monitored_contact
  has_one    :user,         through: :waha_session
  has_one_attached :audio
  has_many   :provider_usages, -> { order(created_at: :desc) }

  enum :status, {
    processing: "processing",
    completed:  "completed",
    failed:     "failed"
  }, default: :processing

  enum :direction, {
    incoming: "incoming",
    outgoing: "outgoing"
  }, default: :incoming

  scope :completed, -> { where(status: :completed) }
  scope :this_month, -> { where("transcriptions.created_at >= ?", Time.current.beginning_of_month) }
  scope :recent, -> { order("transcriptions.created_at" => :desc) }

  # True when the Pro AI-formatted content is present.
  def formatted?
    summary.present? || full_formatted.present?
  end

  def llm_output_json
    payload = {}
    payload[:summary] = summary if summary.present?
    payload[:full_formatted] = full_formatted if full_formatted.present?
    return if payload.empty?

    JSON.pretty_generate(payload)
  end

  def reply_text(user_override = user)
    body = full_formatted.presence || transcript
    return if body.blank?

    if user_override&.pro?
      if user_override.polished? && summary.present? && summary.length < body.length
        [
          "📝 *Resumo rápido*\n\n#{summary}",
          "───────────────",
          "📄 *Transcrição completa*\n\n_#{body}_"
        ].join("\n\n")
      else
        "📄 *Transcrição*\n\n#{body}"
      end
    elsif user_override&.free?
      "📄 *Transcrição*\n\n#{transcript}\n\n---\n_via EscreveZap_"
    else
      "📄 *Transcrição*\n\n#{transcript}"
    end
  end
end
