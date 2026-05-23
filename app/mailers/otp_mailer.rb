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
end
