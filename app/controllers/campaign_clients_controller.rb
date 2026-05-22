class CampaignClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!
  before_action :require_campaigns!
  before_action :set_campaign, only: [:create]
  before_action :set_campaign_client, only: [:show, :update, :destroy]
  layout "authenticated"

  def show
    @installments  = @campaign_client.installments.order(:due_date)
    @notifications = @campaign_client.notifications.order(created_at: :desc).limit(50)
  end

  def create
    ActiveRecord::Base.transaction do
      client = resolve_client!
      @campaign_client = @campaign.campaign_clients.build(
        client:        client,
        amount:        params.dig(:campaign_client, :amount).presence,
        next_due_date: params.dig(:campaign_client, :next_due_date).presence
      )
      @campaign_client.save!
    end
    redirect_to @campaign, notice: "Cliente adicionado à campanha."
  rescue ActiveRecord::RecordNotFound
    redirect_to @campaign, alert: "Cliente não encontrado."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @campaign, alert: e.record.errors.full_messages.to_sentence
  rescue RuntimeError => e
    redirect_to @campaign, alert: e.message
  end

  def update
    if @campaign_client.update(campaign_client_params)
      if turbo_frame_request?
        flash[:notice] = "Alterações salvas com sucesso."
        render turbo_stream: [
          turbo_stream.update("modal", ""),
          turbo_stream.refresh
        ]
      elsif params[:from_client]
        redirect_to client_path(@campaign_client.client), notice: "Atualizado com sucesso."
      else
        redirect_to @campaign_client.campaign, notice: "Atualizado com sucesso."
      end
    else
      if turbo_frame_request?
        @installments  = @campaign_client.installments.order(:due_date)
        @notifications = @campaign_client.notifications.order(created_at: :desc).limit(50)
        render :show, status: :unprocessable_entity
      else
        redirect_to @campaign_client.campaign, alert: @campaign_client.errors.full_messages.to_sentence
      end
    end
  end

  def destroy
    campaign = @campaign_client.campaign
    @campaign_client.soft_delete!
    redirect_to campaign, notice: "Cliente removido da campanha."
  end

  private

  def set_campaign
    @campaign = current_user.company.campaigns.find(params[:campaign_id])
  end

  def set_campaign_client
    @campaign_client = CampaignClient
      .joins(:campaign)
      .where(campaigns: { company_id: current_user.company_id })
      .find(params[:id])
  end

  def resolve_client!
    if params.dig(:campaign_client, :client_id).present?
      current_user.company.clients.find(params[:campaign_client][:client_id])
    elsif params.dig(:campaign_client, :new_client, :name).present?
      current_user.company.clients.create!(
        name:         params.dig(:campaign_client, :new_client, :name).to_s.strip,
        phone_number: params.dig(:campaign_client, :new_client, :phone_number).to_s.strip.presence
      )
    else
      raise "Informe um cliente ou preencha o nome do novo cliente."
    end
  end

  def campaign_client_params
    params.require(:campaign_client).permit(:client_id, :amount, :next_due_date, :status)
  end
end
