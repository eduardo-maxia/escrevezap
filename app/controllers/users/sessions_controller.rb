class Users::SessionsController < Devise::SessionsController
  layout "auth"

  # GET /app/entrar
  def new
    @user = User.new
  end

  # POST /app/entrar
  def create
    email = params.dig(:user, :email).to_s.strip.downcase

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      flash.now[:alert] = t("auth.magic_link.invalid_email")
      @user = User.new(email: email)
      return render :new, status: :unprocessable_entity
    end

    user = User.find_or_create_by!(email: email)
    token = SignInToken.generate!(user: user)
    SessionMailer.magic_link(user, token).deliver_later

    redirect_to check_inbox_path(email: email)
  end

  # GET /app/entrar/verificar/:token
  def magic_link
    token_record = SignInToken.active.find_by(token: params[:token])

    if token_record.nil?
      redirect_to new_user_session_path, alert: t("auth.magic_link.expired")
      return
    end

    token_record.consume!
    sign_in(:user, token_record.user)
    redirect_to after_sign_in_path_for(token_record.user), notice: t("auth.magic_link.welcome")
  end

  # GET /app/entrar/confirmar
  def check_inbox
    @email = params[:email]
  end

  # DELETE /app/sair
  def destroy
    super
  end

  private

  def after_sign_out_path_for(_resource_or_scope)
    new_user_session_path
  end
end
