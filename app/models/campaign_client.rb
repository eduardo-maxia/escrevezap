class CampaignClient < ApplicationRecord
  belongs_to :campaign
  belongs_to :client

  has_many :installments, dependent: :destroy
  has_many :notifications, dependent: :destroy

  enum :status, { active: "active", inactive: "inactive", paused: "paused", completed: "completed" }, default: :active

  scope :visible, -> { where.not(status: :inactive) }

  validates :amount,  presence: true, numericality: { greater_than: 0, message: "deve ser maior que zero" }
  validates :due_day, presence: true, inclusion: { in: 1..30, message: "deve ser entre 1 e 30" }

  # Rule 1: create first installment right after the campaign_client is created.
  after_create :create_initial_installment

  # Rule 2: when due day or amount changes, cancel future pending installments
  # (cascading to their notifications) and schedule a fresh one.
  before_update :sync_future_installments,
                if: -> { due_day_changed? || amount_changed? }

  def soft_delete!
    update_columns(status: "inactive", inactivated_at: Time.current)
  end

  # Returns the next upcoming occurrence of due_day on or after today.
  def upcoming_due_date
    today = Date.current
    this_month = safe_due_date(today.year, today.month)
    this_month >= today ? this_month : safe_due_date((today >> 1).year, (today >> 1).month)
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

  # Builds a Date for the given year/month, clamping due_day to the last valid day of that month.
  def safe_due_date(year, month)
    max_day = Date.new(year, month, -1).day
    Date.new(year, month, [due_day, max_day].min)
  end

  def create_initial_installment
    installments.create!(
      due_date: upcoming_due_date,
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

    next_due = upcoming_due_date

    # If only amount changed and there's already a paid installment this month, skip.
    if !due_day_changed? && installments.exists?(status: :paid, due_date: next_due.beginning_of_month..next_due.end_of_month)
      return
    end

    # Build the replacement installment and validate before the parent saves.
    new_inst = installments.build(
      due_date: next_due,
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
