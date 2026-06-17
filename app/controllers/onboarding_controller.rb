class OnboardingController < ApplicationController
  layout "auth"
  before_action :authenticate_user!
  before_action :redirect_if_completed, only: [:show, :reconnect]
  before_action :load_or_build_waha_session, only: [:show, :reconnect]

  def show
    if @waha_session.working?
      current_user.update!(onboarding_completed: true, contacts_intro_dismissed: true) unless current_user.onboarding_completed?
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
