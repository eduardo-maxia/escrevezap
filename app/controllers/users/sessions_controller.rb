# Passwordless sessions controller.
#
# Flow:
#   1. GET  /app/users/sign_in   →  #new      — render email entry form
#   2. POST /app/users/sign_in   →  #create   — find/create user, send OTP, redirect to /verify
#   3. GET  /app/users/verify    →  #verify   — render 6-digit OTP form (email kept in session)
#   4. POST /app/users/verify    →  #confirm  — validate code, sign in
#   5. POST /app/users/resend    →  #resend   — re-send code (cooldown protected)
class Users::SessionsController < Devise::SessionsController
  skip_before_action :require_no_authentication, only: [:verify, :confirm, :resend]

  # If the user is already signed in, silently redirect to the app root
  # instead of showing Devise's "Você já está autenticado." flash.
  def require_no_authentication
    if user_signed_in?
      redirect_to after_sign_in_path_for(current_user)
    end
  end

  # GET /app/users/sign_in
  def new
    self.resource = resource_class.new
    respond_with(resource, serialize_options(resource))
  end

  # POST /app/users/sign_in
  # Accepts { user: { email: } } — generates an OTP and emails it.
  def create
    email = sign_in_params[:email].to_s.strip.downcase

    if email.blank? || email !~ URI::MailTo::EMAIL_REGEXP
      flash.now[:alert] = "Informe um e-mail válido."
      self.resource = resource_class.new(email: email)
      return render :new, status: :unprocessable_entity
    end

    user = User.find_or_initialize_by(email: email)

    if user.new_record?
      # First-time visitor — create a passwordless account on the fly.
      user.save!
    end

    code = user.generate_otp!
    OtpMailer.send_code(user, code).deliver_later

    session[:otp_user_id] = user.id
    redirect_to verify_otp_path
  end

  # GET /app/users/verify
  def verify
    user = pending_otp_user
    return redirect_to new_user_session_path, alert: "Comece informando seu e-mail." unless user

    @email = user.email
    @resend_in = user.otp_resend_available_in
  end

  # POST /app/users/verify
  def confirm
    user = pending_otp_user
    return redirect_to new_user_session_path, alert: "Sessão de verificação expirada. Tente novamente." unless user

    code = params[:code].to_s.gsub(/\D/, "")

    case user.verify_otp(code)
    when :ok
      session.delete(:otp_user_id)
      sign_in(user)
      redirect_to after_sign_in_path_for(user)
    when :expired
      redirect_to new_user_session_path, alert: "O código expirou. Solicite um novo."
    when :too_many_attempts
      user.clear_otp!
      session.delete(:otp_user_id)
      redirect_to new_user_session_path, alert: "Muitas tentativas. Solicite um novo código."
    when :invalid
      @email = user.email
      @resend_in = user.otp_resend_available_in
      @invalid_code = true
      flash.now[:alert] = "Código incorreto. Verifique e tente novamente."
      render :verify, status: :unprocessable_entity
    end
  end

  # POST /app/users/resend
  def resend
    user = pending_otp_user
    return redirect_to new_user_session_path, alert: "Sessão expirada. Comece novamente." unless user

    unless user.can_resend_otp?
      redirect_to verify_otp_path, alert: "Aguarde alguns segundos antes de pedir outro código."
      return
    end

    code = user.generate_otp!
    OtpMailer.send_code(user, code).deliver_later
    redirect_to verify_otp_path, notice: "Enviamos um novo código para #{user.email}."
  end

  private

  def pending_otp_user
    id = session[:otp_user_id]
    id && User.find_by(id: id)
  end

  def sign_in_params
    params.require(:user).permit(:email)
  end
end
