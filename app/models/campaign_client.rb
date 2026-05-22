class CampaignClient < ApplicationRecord
  belongs_to :campaign
  belongs_to :client

  has_many :installments, dependent: :destroy
  has_many :notifications, dependent: :destroy

  enum :status, { active: "active", inactive: "inactive", paused: "paused", completed: "completed" }, default: :active

  scope :visible, -> { where.not(status: :inactive) }

  validates :amount,        presence: true, numericality: { greater_than: 0, message: "deve ser maior que zero" }
  validates :next_due_date, presence: true
  validate  :next_due_date_not_in_past, if: :next_due_date_changed?

  # Rule 1: create first installment right after the campaign_client is created.
  after_create :create_initial_installment

  # Rule 2: when due date or amount changes, cancel future pending installments
  # (cascading to their notifications) and schedule a fresh one.
  before_update :sync_future_installments,
                if: -> { next_due_date_changed? || amount_changed? }

  def soft_delete!
    update_columns(status: "inactive", inactivated_at: Time.current)
  end

  # Builds the WhatsApp message payload for a given installment,
  # interpolating {{nome}}, {{valor}}, and {{vencimento}} from the campaign template.
  def build_notification_payload(installment)
    body = campaign.template&.dig("body").presence || Campaign::DEFAULT_TEMPLATE_BODY
    amount_str = ActiveSupport::NumberHelper.number_to_currency(
      installment.amount,
      unit: "R$ ", separator: ",", delimiter: ".", precision: 2
    )
    body
      .gsub("{{nome}}",       client.name.to_s)
      .gsub("{{valor}}",      amount_str)
      .gsub("{{vencimento}}", installment.due_date.strftime("%d/%m/%Y"))
  end

  private

  def next_due_date_not_in_past
    return if next_due_date.blank?
    errors.add(:next_due_date, "não pode ser uma data passada") if next_due_date < Date.today
  end

  def create_initial_installment
    installments.create!(
      due_date: next_due_date,
      amount:   amount,
      status:   :pending
    )
  end

  def sync_future_installments
    # Cancel every pending future (>= today) installment, including its pending notifications.
    future_pending = installments.pending.where("due_date >= ?", Date.today)

    future_pending.each do |inst|
      inst.notifications
          .where(notification_status: :pending)
          .update_all(
            notification_status: "cancelled",
            cancellation_reason: "Parcela cancelada por atualização do cliente",
            updated_at:          Time.current
          )
      inst.update_columns(status: "cancelled")
    end

    # Build the replacement installment and validate before the parent saves.
    new_inst = installments.build(
      due_date: next_due_date,
      amount:   amount,
      status:   :pending
    )

    unless new_inst.valid?
      new_inst.errors.each { |err| errors.add(:base, err.full_message) }
      throw :abort
    end

    new_inst.save!
  end
end
