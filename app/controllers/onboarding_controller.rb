class OnboardingController < ApplicationController
  before_action :authenticate_user!
  layout "onboarding"

  # ── Step 1 – Name + Company ──────────────────────────────────────────
  def step1
    @name         = current_user.name.to_s
    @company_name = current_user.company&.name.to_s
  end

  def create_step1
    @name         = params[:name].to_s.strip
    @company_name = params[:company_name].to_s.strip

    if @name.blank? || @company_name.blank?
      @error = "Por favor, preencha todos os campos."
      render :step1, status: :unprocessable_entity and return
    end

    company = current_user.company || Company.new
    company.name = @company_name

    if company.save
      current_user.update!(name: @name, company: company, role: "owner")
      redirect_to onboarding_step2_path
    else
      @error = company.errors.full_messages.to_sentence
      render :step1, status: :unprocessable_entity
    end
  end

  # ── Step 2 – WhatsApp connect ────────────────────────────────────────
  def step2
    ensure_company!
    chip = current_user.company.chips.find_by(provider: :waha)
    redirect_to onboarding_step3_path if chip&.waha_status == "working"
  end

  def create_step2
    redirect_to onboarding_step3_path
  end

  # POST /onboarding/step3/start_session
  # Creates (or resumes) the Waha session for this company's chip.
  # Responds with { chip_id: } so the browser can subscribe to ChipStatusChannel.
  def start_waha_session
    ensure_company!
    company = current_user.company

    chip = company.chips.first_or_create!(
      name:        "Chip Principal",
      provider:    "waha",
      waha_status: "pending"
    )

    if chip.waha_session.blank?
      chip.update!(waha_session: "chip_#{chip.id}")
    end

    unless %w[working starting scan_qr_code].include?(chip.waha_status)
      waha = Waha::Client.new(session: chip.waha_session)
      begin
        waha.sessions.create
      rescue ApiRequest::ApiClientError
        # Session already exists in Waha – restart it
        waha.sessions.restart
      end
    end

    render json: { chip_id: chip.id, status: chip.waha_status }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /onboarding/step2/chip_status
  # Polling fallback: returns the current waha_status for this company's chip.
  def chip_status
    ensure_company!
    chip = current_user.company.chips.find_by(provider: :waha)
    render json: { status: chip&.waha_status || "pending" }
  end

  # POST /onboarding/step3/request_pairing_code
  # Requests a pairing code from Waha for the given phone number.
  # Responds with { code: "ABCD-ABCD" }.
  def request_waha_pairing_code
    ensure_company!
    chip = current_user.company.chips.first

    phone_number = params[:phone_number].to_s.gsub(/\D/, "")
    if phone_number.blank?
      render json: { error: "Número de telefone inválido." }, status: :unprocessable_entity
      return
    end

    result = Waha::Client.new(session: chip.waha_session)
                         .sessions
                         .request_pairing_code(phone_number: phone_number)

    render json: { code: result["code"] }
  rescue ApiRequest::ApiClientError => e
    render json: { error: "Não foi possível gerar o código. Tente escanear o QR code." }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /onboarding/step3/qr
  # Proxies the QR image from Waha as base64 JSON.
  # The browser fetches this when it receives a SCAN_QR_CODE status via ActionCable.
  def waha_qr_code
    ensure_company!
    chip = current_user.company.chips.first

    result = Waha::Client.new(session: chip.waha_session).sessions.qr
    render json: result
  rescue ApiRequest::ApiClientError, ApiRequest::ApiConnectionError
    render json: { error: "QR code indisponível. Aguarde e tente novamente." }, status: :service_unavailable
  end

  # GET /onboarding/step3/check_whatsapp?phone=5511999999999
  # Checks whether a phone number has a WhatsApp account via the Waha contacts API.
  # Responds with { exists: true/false, chat_id: "...@c.us" }.
  def check_whatsapp_exists
    ensure_company!
    chip = current_user.company.chips.first

    phone = params[:phone].to_s.gsub(/\D/, "")
    if phone.blank? || phone.length < 10
      render json: { error: "Número inválido." }, status: :unprocessable_entity and return
    end

    result = Waha::Client.new(session: chip.waha_session).contacts.check_exists(phone: phone)
    render json: { exists: result["numberExists"], chat_id: result["chatId"] }
  rescue ApiRequest::ApiClientError, ApiRequest::ApiConnectionError, ApiRequest::ApiServerError
    render json: { error: "Não foi possível verificar." }, status: :service_unavailable
  end

  # ── Step 3 – Test message ────────────────────────────────────────────
  def step3
    ensure_company!
    @notification = Notification.find_by(id: params[:notification_id])
  end

  def create_step3
    ensure_company!
    company = current_user.company

    chip = company.chips.first_or_create!(
      name:        "Chip Principal",
      provider:    "waha",
      waha_status: "pending"
    )

    campaign = company.campaigns.first_or_create!(
      name:               "Campanha de Cobrança",
      chip:               chip,
      recurrence_pattern: "monthly",
      start_time:         "08:00",
      end_time:           "18:00",
      status:             "active"
    )

    phone = params[:phone_number].to_s.strip.gsub(/\D/, "")

    if phone.blank?
      @error = "Informe um número de WhatsApp válido."
      render :step3, status: :unprocessable_entity and return
    end

    client = company.clients.create!(
      name:         current_user.name.presence || current_user.email.split("@").first.capitalize,
      phone_number: phone,
      company:      company
    )

    campaign_client = CampaignClient.create!(
      campaign:      campaign,
      client:        client,
      amount:        1,
      next_due_date: Date.tomorrow,
      status:        "active"
    )

    # Remember this test client so we can delete it when onboarding finishes.
    session[:onboarding_test_client_id] = client.id

    notification = Notification.create!(
      campaign_client:     campaign_client,
      sender:              chip,
      event_type:          "message",
      scheduled_at:        Time.current,
      payload:             "Olá, #{client.name}! 👋 Este é um teste do Cobrança em Dia. Sua régua de cobranças está pronta para funcionar. 🚀"
    )

    SendMessageJob.perform_later(notification.id)
    redirect_to onboarding_step3_path(notification_id: notification.id)
  end

  # ── Skip / Complete ──────────────────────────────────────────────────
  def skip
    cleanup_test_client
    current_user.update!(onboarding_completed: true)
    redirect_to authenticated_root_path, notice: "Onboarding pulado. Você pode configurar tudo pelo dashboard."
  end

  def complete
    cleanup_test_client
    current_user.update!(onboarding_completed: true)
    redirect_to authenticated_root_path, notice: "Tudo pronto! Bem-vindo ao Cobrança em Dia 🎉"
  end

  private

  def cleanup_test_client
    client_id = session.delete(:onboarding_test_client_id)
    return unless client_id

    client = current_user.company&.clients&.find_by(id: client_id)
    client&.destroy
  end

  def ensure_company!
    redirect_to onboarding_step1_path unless current_user.company
  end
end
