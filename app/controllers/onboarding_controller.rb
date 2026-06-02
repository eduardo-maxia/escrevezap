class OnboardingController < ApplicationController
  layout "auth"
  before_action :authenticate_user!
  before_action :redirect_if_completed, only: [:show, :reconnect]
  before_action :load_or_build_waha_session, only: [:show, :reconnect]

  def show
    if @waha_session.working?
      current_user.complete_onboarding! unless current_user.onboarding_completed?
      redirect_to authenticated_root_path and return
    end

    begin
      start_onboarding_session!
    rescue => e
      flash.now[:alert] = "Não foi possível iniciar a sessão do WhatsApp: #{human_error_message(e)}"
    end
  end

  def reconnect
    begin
      reconnect_onboarding_session!
      render json: { status: @waha_session.reload.waha_status }
    rescue => e
      render json: { error: "Não foi possível reconectar: #{human_error_message(e)}" }, status: :service_unavailable
    end
  end

  def skip_connection
    current_user.update!(
      onboarding_completed: true,
      contacts_intro_dismissed: true
    )

    redirect_to authenticated_root_path, notice: "Você pode conectar seu WhatsApp depois, na aba WhatsApp."
  end

  # Step 3 — choose how transcriptions are triggered.
  # "reaction" (default)    → user reacts 👀 on the audio they want transcribed.
  # "monitored_contacts"    → user picks specific contacts to monitor.
  def step_mode
    @waha_session = current_user.waha_session
    redirect_to authenticated_root_path and return if @waha_session.nil?
    redirect_to authenticated_root_path and return if current_user.contacts_intro_dismissed?
  end

  def set_mode
    @waha_session = current_user.waha_session
    redirect_to authenticated_root_path and return if @waha_session.nil?

    mode = params[:transcription_mode].to_s
    unless WahaSession.transcription_modes.key?(mode)
      redirect_to onboarding_step_mode_path, alert: "Selecione uma opção." and return
    end

    @waha_session.update!(transcription_mode: mode)

    if @waha_session.mode_reaction?
      current_user.update!(contacts_intro_dismissed: true)
      redirect_to authenticated_root_path,
                  notice: "Pronto! Reaja com 👀 em qualquer áudio para transcrever."
    else
      redirect_to onboarding_step3_path
    end
  end

  def step3
    redirect_to authenticated_root_path and return if current_user.contacts_intro_dismissed?
    redirect_to onboarding_step_mode_path and return unless current_user.waha_session&.mode_monitored_contacts?

    @contact = waha_session.monitored_contacts.build(direction: :both)
  end

  def step3_done
    redirect_to authenticated_root_path unless current_user.contacts_intro_dismissed?
  end

  def step3_whatsapp_contacts
    unless waha_session&.working?
      render json: { contacts: [] } and return
    end

    raw = waha_session.waha_client.contacts.list_all
    contacts = raw.map do |c|
      phone = c["id"].to_s.gsub("@c.us", "")
      name  = c["name"].presence || c["pushname"].presence
      { phone: phone, name: name, label: [name, phone].compact.join(" · ") }
    end.sort_by { |c| c[:name].to_s.downcase }

    render json: { contacts: contacts }
  rescue => e
    render json: { contacts: [], error: e.message }
  end

  def create_contact
    @contact = waha_session.monitored_contacts.build(contact_params)

    if @contact.save
      FetchMonitoredContactProfilePictureJob.perform_later(@contact.id)
      current_user.update!(contacts_intro_dismissed: true) unless current_user.contacts_intro_dismissed?
      redirect_to onboarding_step3_done_path
    else
      render :step3, status: :unprocessable_entity
    end
  end

  def dismiss_contacts
    current_user.update!(contacts_intro_dismissed: true)
    redirect_to authenticated_root_path
  end

  private

  def load_or_build_waha_session
    @waha_session = current_user.waha_session || current_user.build_waha_session
    @waha_session.save! if @waha_session.new_record?
  end

  def start_onboarding_session!
    return if @waha_session.working?

    case @waha_session.waha_status
    when "starting", "scan_qr_code"
      ensure_session_exists_in_waha!
    else
      start_existing_or_create_session!
    end
  end

  def reconnect_onboarding_session!
    begin
      @waha_session.waha_client.sessions.restart
      @waha_session.update!(waha_status: :starting)
    rescue => e
      raise unless missing_waha_session_error?(e)

      @waha_session.connect!
    end
  end

  def start_existing_or_create_session!
    begin
      @waha_session.waha_client.sessions.start
      @waha_session.update!(waha_status: :starting)
    rescue => e
      raise unless missing_waha_session_error?(e)

      @waha_session.connect!
    end
  end

  def ensure_session_exists_in_waha!
    @waha_session.waha_client.sessions.get
  rescue => e
    raise unless missing_waha_session_error?(e)

    @waha_session.connect!
  end

  def missing_waha_session_error?(error)
    [error, error.cause].compact.any? do |err|
      next false unless err.is_a?(ApiRequest::ApiClientError)

      message = err.message.to_s.downcase
      has_404 = message.include?(" 404 ") || message.include?("404")
      missing_session = message.include?("session") && (
        message.include?("not found") ||
        message.include?("does not exist") ||
        message.include?("unknown")
      )

      has_404 || missing_session
    end
  end

  def human_error_message(error)
    message = error.message.to_s
    return "Tente novamente em alguns segundos." if message.blank?

    message
  end

  def redirect_if_completed
    redirect_to authenticated_root_path if current_user.onboarding_completed?
  end

  def contact_params
    params.require(:monitored_contact).permit(:phone_number, :display_name, :direction, :enabled)
  end

  def waha_session
    @waha_session ||= current_user.waha_session
  end
end
