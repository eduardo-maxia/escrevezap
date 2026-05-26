class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!
  layout "authenticated"

  def show; end

  # ── Empresa ────────────────────────────────────────────────────────
  def empresa
    @company = current_user.company
  end

  def update_empresa
    @company = current_user.company
    if @company.update(empresa_params)
      redirect_to settings_empresa_path, notice: "Dados da empresa atualizados."
    else
      render :empresa, status: :unprocessable_entity
    end
  end

  # ── Perfil ─────────────────────────────────────────────────────────
  def perfil
    if session[:pending_email_change]
      @show_otp     = true
      @pending_email = session[:pending_email_change]
      @resend_in    = current_user.otp_resend_available_in
    end
  end

  def update_perfil
    new_email = perfil_params[:email].to_s.strip.downcase
    new_name  = perfil_params[:name].to_s.strip

    if new_email == current_user.email
      # No email change — just update name
      if current_user.update_without_password(name: new_name)
        redirect_to settings_perfil_path, notice: "Perfil atualizado com sucesso."
      else
        redirect_to settings_perfil_path, alert: current_user.errors.full_messages.to_sentence
      end
      return
    end

    # Email is changing — validate format + uniqueness first
    unless new_email.match?(URI::MailTo::EMAIL_REGEXP)
      redirect_to settings_perfil_path, alert: "Informe um e-mail válido."
      return
    end

    if User.where.not(id: current_user.id).exists?(email: new_email)
      redirect_to settings_perfil_path, alert: "Este e-mail já está em uso."
      return
    end

    # Save name right away (no validation issues for name-only change)
    current_user.update_column(:name, new_name) if new_name != current_user.name

    # Send OTP to the new email and store pending state in session
    code = current_user.generate_otp!
    OtpMailer.confirm_email_change(current_user, code, new_email).deliver_later
    session[:pending_email_change] = new_email

    redirect_to settings_perfil_path
  end

  def verify_email_change
    pending_email = session[:pending_email_change]
    return redirect_to settings_perfil_path, alert: "Nenhuma mudança de e-mail pendente." unless pending_email

    code = params[:code].to_s.gsub(/\D/, "")

    case current_user.verify_otp(code)
    when :ok
      session.delete(:pending_email_change)
      current_user.update!(email: pending_email)
      redirect_to settings_perfil_path, notice: "E-mail atualizado para #{pending_email}."
    when :expired
      redirect_to settings_perfil_path, alert: "O código expirou. Solicite um novo."
    when :too_many_attempts
      current_user.clear_otp!
      session.delete(:pending_email_change)
      redirect_to settings_perfil_path, alert: "Muitas tentativas incorretas. Reinicie o processo."
    when :invalid
      redirect_to settings_perfil_path, alert: "Código incorreto. Tente novamente."
    end
  end

  def resend_email_change
    pending_email = session[:pending_email_change]
    return redirect_to settings_perfil_path unless pending_email

    unless current_user.can_resend_otp?
      return redirect_to settings_perfil_path, alert: "Aguarde antes de pedir outro código."
    end

    code = current_user.generate_otp!
    OtpMailer.confirm_email_change(current_user, code, pending_email).deliver_later
    redirect_to settings_perfil_path, notice: "Novo código enviado para #{pending_email}."
  end

  def cancel_email_change
    session.delete(:pending_email_change)
    current_user.clear_otp!
    redirect_to settings_perfil_path
  end

  # ── Senha ──────────────────────────────────────────────────────────
  def senha; end

  def update_senha
    if current_user.update_with_password(senha_params)
      bypass_sign_in(current_user)
      redirect_to settings_senha_path, notice: "Senha alterada com sucesso."
    else
      render :senha, status: :unprocessable_entity
    end
  end

  # ── Cobrança (only when feature_campanhas = false) ─────────────────
  def cobranca
    @campaign = current_user.company.campaigns.first
    @chip     = current_user.company.chips.first
  end

  def update_cobranca
    @campaign = current_user.company.campaigns.first
    @chip     = current_user.company.chips.first
    if @campaign&.update(cobranca_params)
      redirect_to settings_cobranca_path, notice: "Configurações de cobrança atualizadas."
    else
      render :cobranca, status: :unprocessable_entity
    end
  end

  # ── Notificações ───────────────────────────────────────────────────
  def notifications; end

  def update_notifications
    if current_user.update(notification_prefs_params)
      redirect_to settings_notifications_path, notice: "Preferências de notificação salvas."
    else
      redirect_to settings_notifications_path, alert: "Não foi possível salvar as preferências."
    end
  end

  private

  def empresa_params
    params.require(:company).permit(:name)
  end

  def perfil_params
    params.require(:user).permit(:name, :email)
  end

  def senha_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def cobranca_params
    params.require(:campaign).permit(:start_time, :end_time, template: [:body])
  end

  def notification_prefs_params
    params.require(:user).permit(:notif_proof_attached, :notif_chip_disconnected)
  end
end
