class Campaign < ApplicationRecord
  belongs_to :company
  belongs_to :chip

  has_many :campaign_clients, dependent: :destroy
  has_many :clients, through: :campaign_clients
  has_many :notifications, through: :campaign_clients

  enum :status, { draft: "draft", active: "active", paused: "paused", finished: "finished" }
  enum :recurrence_pattern, { monthly: "monthly" }

  DEFAULT_TEMPLATE_BODY =
    "Ol\u00e1, {{nome}}! \u{1F44B} Sua parcela de {{valor}} vence hoje " \
    "({{vencimento}}). " \
    "Realize o pagamento para manter seu servi\u00e7o em dia. \u{1F60A}"

  before_save :set_default_template

  private

  def set_default_template
    self.template = { "body" => DEFAULT_TEMPLATE_BODY } if template&.dig("body").blank?
  end
end
