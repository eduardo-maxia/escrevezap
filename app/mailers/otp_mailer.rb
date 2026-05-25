class OtpMailer < ApplicationMailer
  def send_code(user, code)
    @user = user
    @code = code
    @expires_in_minutes = User::OTP_EXPIRY / 60

    mail(
      to: @user.email,
      subject: "Seu código de acesso: #{code}"
    )
  end

  def confirm_email_change(user, code, new_email)
    @user               = user
    @code               = code
    @new_email          = new_email
    @expires_in_minutes = User::OTP_EXPIRY / 60

    mail(
      to: new_email,
      subject: "Confirme seu novo e-mail: #{code}"
    )
  end

  def invite(user, invited_by)
    @user       = user
    @invited_by = invited_by
    @company    = user.company
    @login_url  = new_user_session_url

    mail(
      to: user.email,
      subject: "Você foi convidado para #{@company.name} no Cobrança em Dia"
    )
  end
end
