class ShareReceiptsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!

  # Skip CSRF only for the OS share-sheet POST — it carries no Rails token.
  # The service worker intercepts this in normal PWA flow; this is a fallback.
  skip_before_action :verify_authenticity_token, only: :receive

  def new
    @token = params[:token]
    @query = params[:q].to_s.strip

    scope = base_scope
    scope = scope.where("clients.name ILIKE ?", "%#{@query}%") if @query.present?

    @pagy, @installments = pagy(scope, limit: 20)
  end

  def receive
    # The service worker should have intercepted this POST when the PWA is active.
    # Redirect to the picker with an informative message.
    redirect_to share_receipt_path,
                alert: "Para usar esta função o app precisa estar instalado e aberto no celular."
  end

  def attach
    installment = company_installments.find(params[:installment_id])

    attrs = { proof_image: params[:receipt] }
    attrs[:status] = :paid if installment.pending?

    if installment.update(attrs)
      render json: { ok: true }
    else
      render json: { ok: false, errors: installment.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  private

  def base_scope
    Installment
      .joins(campaign_client: [:client, { campaign: :company }])
      .where(companies: { id: current_user.company_id })
      .selectable_for_receipt
      .order("installments.due_date ASC")
  end

  def company_installments
    Installment
      .joins(campaign_client: { campaign: :company })
      .where(companies: { id: current_user.company_id })
  end
end
