class Installment < ApplicationRecord
  has_one_attached :proof_image

  belongs_to :campaign_client

  has_many :notifications, dependent: :nullify

  enum :status, { pending: "pending", paid: "paid", cancelled: "cancelled" }

  scope :valid, -> { where.not(status: :cancelled) }

  # Installments that should appear in the share-receipt picker:
  # pending ones AND paid ones that still have no proof attached.
  scope :selectable_for_receipt, -> {
    where(
      "installments.status = 'pending' OR " \
      "(installments.status = 'paid' AND NOT EXISTS (" \
      "  SELECT 1 FROM active_storage_attachments asa" \
      "  WHERE asa.record_type = 'Installment'" \
      "    AND asa.record_id   = installments.id" \
      "    AND asa.name        = 'proof_image'" \
      "))"
    )
  }

  validate :single_active_installment_per_month

  after_update :purge_proof_if_not_paid
  after_update :cancel_pending_notifications_if_cancelled

  private

  def cancel_pending_notifications_if_cancelled
    return unless saved_change_to_status? && cancelled?

    notifications.where(notification_status: :pending).update_all(notification_status: "cancelled")
  end

  def purge_proof_if_not_paid
    proof_image.purge if !paid? && proof_image.attached?
  end

  # Rule 5: at most one non-cancelled installment per campaign_client per calendar month.
  def single_active_installment_per_month
    return if campaign_client_id.blank? || due_date.blank?

    scope = Installment
              .where(campaign_client_id: campaign_client_id)
              .where.not(status: :cancelled)
              .where("DATE_TRUNC('month', due_date) = DATE_TRUNC('month', ?::date)", due_date)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:due_date, "já existe uma parcela ativa neste mês para este cliente") if scope.exists?
  end
end
