class BillingController < ApplicationController
  layout "authenticated"
  before_action :authenticate_user!
  before_action :ensure_valid_plan, only: [:upgrade, :change_plan, :change_plan_confirm]

  def show
    @subscription = current_user.subscription
  end

  # GET /app/assinatura/cancelar — modal
  def cancel_confirm
    @subscription = current_user.subscription
    render layout: false
  end

  # GET /app/assinatura/trocar-plano/confirmar — modal
  def change_plan_confirm
    @subscription = current_user.subscription
    @plan         = params[:plan].to_s
    render layout: false
  end

  # DELETE /app/assinatura/cancelar
  def cancel
    subscription = current_user.subscription

    unless subscription&.active_or_trialing?
      redirect_to billing_path, alert: "Você não possui uma assinatura ativa." and return
    end

    response = Abacatepay::Client.new.subscriptions.cancel(
      id: subscription.abacatepay_subscription_id
    )

    unless response["success"]
      Rails.logger.error "[BillingController#cancel] AbacatePay error: #{response['error']}"
      redirect_to billing_path, alert: "Não foi possível cancelar. Tente novamente." and return
    end

    # Update locally — webhook will also fire but this keeps the UI in sync
    subscription.update!(status: :cancelled, cancelled_at: Time.current)
    current_user.update!(plan: :free)

    redirect_to billing_path, notice: "Assinatura cancelada. Acesso ao plano gratuito a partir de agora."
  rescue => e
    Rails.logger.error "[BillingController#cancel] #{e.message}"
    redirect_to billing_path, alert: "Erro ao cancelar. Tente novamente."
  end

  # POST /app/assinatura/trocar-plano
  def change_plan
    plan = params[:plan].to_s

    subscription = current_user.subscription
    unless subscription&.active_or_trialing?
      redirect_to billing_path, alert: "Você não possui uma assinatura ativa." and return
    end

    if subscription.plan == plan
      redirect_to billing_path, notice: "Você já está neste plano." and return
    end

    product_id = case plan
                 when "basic" then Rails.application.credentials.dig(:abacatepay, :product_basic_id)
                 when "pro"   then Rails.application.credentials.dig(:abacatepay, :product_pro_id)
                 end

    if product_id.blank?
      redirect_to billing_path, alert: "Checkout indisponível no momento. Tente novamente." and return
    end

    plan_rank = { "basic" => 1, "pro" => 2 }
    upgrading = plan_rank[plan].to_i > plan_rank[subscription.plan].to_i

    if upgrading
      _change_plan_upgrade(subscription, plan, product_id)
    else
      _change_plan_downgrade(subscription, plan, product_id)
    end
  rescue => e
    Rails.logger.error "[BillingController#change_plan] #{e.message}"
    redirect_to billing_path, alert: "Erro ao alterar o plano. Tente novamente."
  end

  # POST /app/upgrade
  def upgrade
    plan = params[:plan].to_s

    product_id = case plan
                 when "basic" then Rails.application.credentials.dig(:abacatepay, :product_basic_id)
                 when "pro"   then Rails.application.credentials.dig(:abacatepay, :product_pro_id)
                 end

    if product_id.blank?
      Rails.logger.error "[BillingController#upgrade] product_id não configurado para o plano '#{plan}'"
      redirect_to billing_path, alert: "Checkout indisponível no momento. Tente novamente mais tarde." and return
    end

    external_id = "user_#{current_user.id}:#{plan}:#{Time.current.to_i}"

    response = Abacatepay::Client.new.subscriptions.create(
      product_id:     product_id,
      external_id:    external_id,
      completion_url: billing_success_url(plan: plan),
      return_url:     billing_url
    )

    unless response["success"]
      error_msg = response["error"].presence || "Erro desconhecido"
      Rails.logger.error "[BillingController#upgrade] AbacatePay error: #{error_msg}"
      redirect_to billing_path, alert: "Não foi possível iniciar o checkout. Tente novamente." and return
    end

    checkout_url = response.dig("data", "url")
    redirect_to checkout_url, allow_other_host: true
  rescue => e
    Rails.logger.error "[BillingController#upgrade] #{e.message}"
    redirect_to billing_path, alert: "Erro ao processar checkout. Tente novamente."
  end

  # GET /app/obrigado
  def success
    @plan = params[:plan].to_s
  end

  private

  # Upgrade: create new checkout (pay now) — old subscription cancelled by webhook on completion
  def _change_plan_upgrade(subscription, plan, product_id)
    external_id = "user_#{current_user.id}:#{plan}:#{Time.current.to_i}"

    checkout_response = Abacatepay::Client.new.subscriptions.create(
      product_id:     product_id,
      external_id:    external_id,
      completion_url: billing_success_url(plan: plan),
      return_url:     billing_url
    )

    unless checkout_response["success"]
      Rails.logger.error "[BillingController#change_plan upgrade] Checkout error: #{checkout_response['error']}"
      redirect_to billing_path, alert: "Não foi possível iniciar o checkout. Tente novamente." and return
    end

    redirect_to checkout_response.dig("data", "url"), allow_other_host: true
  end

  # Downgrade: change-plan API → takes effect next billing cycle
  def _change_plan_downgrade(subscription, plan, product_id)
    response = Abacatepay::Client.new.subscriptions.change_plan(
      id:         subscription.abacatepay_subscription_id,
      product_id: product_id
    )

    unless response["success"]
      Rails.logger.error "[BillingController#change_plan downgrade] AbacatePay error: #{response['error']}"
      redirect_to billing_path, alert: "Não foi possível alterar o plano. Tente novamente." and return
    end

    redirect_to billing_path,
      notice: "Downgrade para #{plan.capitalize} agendado. Entra em vigor no próximo ciclo de cobrança."
  end

  def ensure_valid_plan
    plan = params[:plan].to_s
    unless %w[basic pro].include?(plan)
      redirect_to billing_path, alert: "Plano inválido."
    end
  end
end
