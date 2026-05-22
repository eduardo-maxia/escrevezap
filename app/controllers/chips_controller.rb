class ChipsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!
  before_action :set_chip, only: [:show, :destroy, :start_session, :request_pairing_code, :qr_code, :disconnect]
  layout "authenticated"

  def index
    @chips = current_user.company.chips.includes(:campaigns).order(:created_at)
  end

  def new
    @chip = current_user.company.chips.build
  end

  def create
    @chip = current_user.company.chips.build(chip_params)
    @chip.provider    = :waha
    @chip.waha_status = :pending

    if @chip.save
      redirect_to chip_path(@chip), notice: "Chip criado. Agora conecte o WhatsApp."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @active_campaigns = @chip.campaigns.where(status: :active).order(:name)
    @all_campaigns    = @chip.campaigns.order(:name)
  end

  def destroy
    active_count = @chip.campaigns.where(status: :active).count
    if active_count > 0 && params[:confirm_force].blank?
      redirect_to chip_path(@chip),
        alert: "Este chip possui #{active_count} campanha(s) ativa(s). Use o botão de confirmação para excluir mesmo assim."
      return
    end

    if @chip.waha_session.present? && !@chip.pending?
      begin
        Waha::Client.new(session: @chip.waha_session).sessions.stop
      rescue StandardError
        # ignore — session may already be gone
      end
    end

    @chip.destroy
    redirect_to chips_path, notice: "Chip removido com sucesso."
  end

  # POST /chips/:id/start_session
  def start_session
    @chip.update!(waha_session: "chip_#{@chip.id}") if @chip.waha_session.blank?

    unless %w[working starting scan_qr_code].include?(@chip.waha_status)
      waha = Waha::Client.new(session: @chip.waha_session)
      begin
        waha.sessions.create
      rescue ApiRequest::ApiClientError
        waha.sessions.restart
      end
    end

    render json: { chip_id: @chip.id, status: @chip.waha_status }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /chips/:id/request_pairing_code
  def request_pairing_code
    phone_number = params[:phone_number].to_s.gsub(/\D/, "")
    if phone_number.blank?
      render json: { error: "Número inválido." }, status: :unprocessable_entity and return
    end

    result = Waha::Client.new(session: @chip.waha_session)
                         .sessions
                         .request_pairing_code(phone_number: phone_number)
    render json: { code: result["code"] }
  rescue ApiRequest::ApiClientError
    render json: { error: "Não foi possível gerar o código. Tente escanear o QR code." },
           status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /chips/:id/qr_code
  def qr_code
    result = Waha::Client.new(session: @chip.waha_session).sessions.qr
    render json: result
  rescue ApiRequest::ApiClientError, ApiRequest::ApiConnectionError
    render json: { error: "QR code indisponível." }, status: :service_unavailable
  end

  # POST /chips/:id/disconnect
  def disconnect
    if @chip.waha_session.present?
      begin
        Waha::Client.new(session: @chip.waha_session).sessions.stop
      rescue StandardError
        # ignore
      end
    end

    @chip.update(waha_status: :stopped, waha_chat_id: nil)
    redirect_url = params[:source] == "dashboard" ? authenticated_root_path : chip_path(@chip)
    redirect_to redirect_url, notice: "Chip desconectado."
  end

  private

  def set_chip
    @chip = current_user.company.chips.find(params[:id])
  end

  def chip_params
    params.require(:chip).permit(:name)
  end
end
