class Subscription < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true, inclusion: { in: %w[abacatepay inter] }

  enum :status, {
    inactive:  "inactive",
    trialing:  "trialing",
    active:    "active",
    past_due:  "past_due",
    cancelled: "cancelled",
    expired:   "expired"
  }, default: :inactive

  enum :plan, {
    basic: "basic",
    pro:   "pro"
  }, prefix: :sub

  def active_or_trialing?
    active? || trialing?
  end

  def current_period_active?
    current_period_end.present? && current_period_end > Time.current
  end

  def pending_downgrade?
    pending_plan.present?
  end

  def apply_pending_plan!
    return unless pending_plan.present?
    update!(plan: pending_plan, pending_plan: nil)
    user.update!(plan: pending_plan)
  end
end
