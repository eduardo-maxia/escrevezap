class WahaSessionsController < ApplicationController
  layout "authenticated"
  before_action :authenticate_user!
  before_action :load_or_build_session

  # GET /app/waha_session — chip management page (post-onboarding)
  def show
  end

  # GET /app/waha_session/status  (JSON)
  def status
    render json: { status: @waha_session&.waha_status || "pending" }
  end

  # GET /app/waha_session/qr  (JSON)
  def qr
    data = @waha_session.waha_client.sessions.qr
    if data["mimetype"].present? && data["data"].present?
      render json: { qr: "data:#{data['mimetype']};base64,#{data['data']}" }
    else
      render json: { qr: nil }, status: :not_found
    end
  rescue => e
    render json: { qr: nil, error: e.message }, status: :service_unavailable
  end

  # POST /app/waha_session/pairing_code  (JSON)
  def pairing_code
    phone = params[:phone_number].to_s.gsub(/\D/, "")

    if phone.blank?
      render json: { error: "Número de telefone inválido" }, status: :unprocessable_entity
      return
    end

    if @waha_session.waha_status != "scan_qr_code"
      begin
        @waha_session.waha_client.sessions.restart
      rescue => _e
        @waha_session.connect! rescue nil
      end

      @waha_session.update!(waha_status: :starting)

      # Aguarda até 15 segundos para a sessão estar pronta (scan_qr_code)
      15.times do
        session_info = @waha_session.waha_client.sessions.get rescue nil
        if session_info && session_info["status"] == "SCAN_QR_CODE"
          @waha_session.update!(waha_status: :scan_qr_code)
          break
        end
        sleep 1
      end
    end

    result = @waha_session.waha_client.sessions.request_pairing_code(phone_number: phone)
    render json: { code: result["code"] }
  rescue => e
    render json: { error: "Aguarde alguns segundos e tente novamente. (#{e.message})" }, status: :service_unavailable
  end

  # POST /app/waha_session/reconnect
  def reconnect
    begin
      @waha_session.waha_client.sessions.restart
      @waha_session.update!(waha_status: :starting)
      respond_to do |format|
        format.html { redirect_to app_waha_session_path, notice: "Reconectando WhatsApp..." }
        format.json { render json: { status: @waha_session.waha_status } }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to app_waha_session_path, alert: "Erro ao reconectar: #{e.message}" }
        format.json { render json: { error: "Erro ao reconectar: #{e.message}" }, status: :service_unavailable }
      end
    end
  end

  # DELETE /app/waha_session
  def destroy
    @waha_session.disconnect!
    redirect_to app_waha_session_path, notice: "WhatsApp desconectado."
  end

  private

  def load_or_build_session
    @waha_session = current_user.waha_session || current_user.build_waha_session
  end
end
