class ClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!
  before_action :set_client, only: [:show, :update, :destroy]
  layout "authenticated"

  def index
    scope = current_user.company.clients

    if params[:q].present?
      scope = scope.search_by_term(params[:q])
    else
      scope = scope.order(:name)
    end

    case params[:whatsapp]
    when "verified"
      scope = scope.where.not(waha_chat_id: [ nil, "" ])
    when "unverified"
      scope = scope.where(waha_chat_id: [ nil, "" ])
    end

    @pagy, @clients = pagy(scope)
  end

  def show
    if current_user.company.feature_campanhas?
      @campaign_clients = @client.campaign_clients
                                 .visible
                                 .includes(:campaign)
                                 .order("campaigns.name")
      render :show
    else
      @campaign_client  = @client.campaign_clients.visible.first
      @show_cancelled  = params[:show_cancelled] == "1"
      base_installments = @campaign_client&.installments&.order(due_date: :desc)
      @installments = if base_installments
        @show_cancelled ? base_installments : base_installments.where.not(status: :cancelled)
      else
        []
      end

      notif_per_page      = 10
      @notif_page         = (params[:notif_page] || 1).to_i.clamp(1, 9999)
      notif_scope         = @campaign_client&.notifications&.where.not(notification_status: :cancelled)
      @notif_total        = notif_scope&.count || 0
      @notif_total_pages  = [(@notif_total.to_f / notif_per_page).ceil, 1].max
      @notifications      = notif_scope
                              &.includes(:installment)
                              &.order(created_at: :desc)
                              &.offset((@notif_page - 1) * notif_per_page)
                              &.limit(notif_per_page) || []

      render :show_simple
    end
  end

  def new
    @client = current_user.company.clients.build
    @simple_mode = !current_user.company.feature_campanhas?
    @campaign_client = CampaignClient.new if @simple_mode
  end

  def create
    @client = current_user.company.clients.build(client_params)

    if current_user.company.feature_campanhas?
      if @client.save
        redirect_to @client, notice: "Cliente criado com sucesso!"
      else
        render :new, status: :unprocessable_entity
      end
    else
      @simple_mode = true
      @campaign_client = CampaignClient.new(campaign_client_simple_params)
      begin
        ActiveRecord::Base.transaction do
          @client.save!
          campaign = current_user.company.campaigns.first
          raise ActiveRecord::RecordNotFound, "Nenhuma campanha encontrada. Conclua a configuração inicial." unless campaign
          @campaign_client.campaign = campaign
          @campaign_client.client   = @client
          @campaign_client.save!
        end
        redirect_to @client, notice: "Cliente criado com sucesso!"
      rescue ActiveRecord::RecordInvalid
        render :new, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound => e
        @client.errors.add(:base, e.message)
        render :new, status: :unprocessable_entity
      end
    end
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "Cliente atualizado!"
    else
      if current_user.company.feature_campanhas?
        @campaign_clients = @client.campaign_clients.visible.includes(:campaign).order("campaigns.name")
        render :show, status: :unprocessable_entity
      else
        @campaign_client = @client.campaign_clients.visible.first
        @installments    = @campaign_client&.installments&.order(due_date: :desc) || []
        render :show_simple, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @client.destroy
    redirect_to clients_path, notice: "Cliente removido."
  end

  # GET /clients/search?q=...
  def search
    q = params[:q].to_s.strip
    clients = if q.blank?
      current_user.company.clients.none
    else
      current_user.company.clients.search_by_term(q).limit(8)
    end
    render json: clients.map { |c|
      { id: c.id, name: c.name, phone: c.formatted_number || c.phone_number }
    }
  end

  private

  def set_client
    @client = current_user.company.clients.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :email, :phone_number)
  end

  def campaign_client_simple_params
    params.require(:campaign_client).permit(:amount, :next_due_date)
  end
end
