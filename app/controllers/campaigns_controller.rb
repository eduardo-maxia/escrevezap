class CampaignsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!
  before_action :require_campaigns!
  before_action :set_campaign, only: [:show, :update, :destroy]
  layout "authenticated"

  def index
    @campaigns = current_user.company.campaigns
                             .includes(:chip)
                             .order(created_at: :desc)
  end

  def show
    @campaign_clients = @campaign.campaign_clients
                                 .visible
                                 .includes(:client)
                                 .order("clients.name")
    @chips = current_user.company.chips

    notif_scope = @campaign.notifications
                           .joins(campaign_client: :client)
                           .includes(campaign_client: :client, installment: [])
    notif_scope = notif_scope.where("clients.name ILIKE ?", "%#{params[:nq]}%") if params[:nq].present?
    notif_scope = notif_scope.where(notification_status: params[:nstatus]) if params[:nstatus].present?
    notif_scope = notif_scope.where(event_type: params[:ntype]) if params[:ntype].present?
    notif_scope = notif_scope.order(created_at: :desc)
    @pagy_notif, @notifications = pagy(notif_scope, limit: 25, page_param: :npage)
  end

  def new
    @campaign = current_user.company.campaigns.build
    @chips    = current_user.company.chips
  end

  def create
    @campaign = current_user.company.campaigns.build(campaign_params)
    @campaign.recurrence_pattern = :monthly
    if @campaign.save
      redirect_to @campaign, notice: "Campanha criada com sucesso!"
    else
      @chips = current_user.company.chips
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @campaign.update(campaign_params)
      redirect_to @campaign, notice: "Campanha atualizada!"
    else
      @chips = current_user.company.chips
      @campaign_clients = @campaign.campaign_clients.includes(:client).order("clients.name")
      @available_clients = current_user.company.clients.where.not(id: @campaign.client_ids).order(:name)
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_path, notice: "Campanha removida."
  end

  private

  def set_campaign
    @campaign = current_user.company.campaigns.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:name, :chip_id, :start_time, :end_time, :status, template: [:body])
  end
end
