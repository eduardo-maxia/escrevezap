class WahaSessionMailer < ApplicationMailer
  def disconnected(user)
    @user = user

    mail(
      to:      @user.email,
      subject: "⚠️ Seu WhatsApp foi desconectado do EscreveZap"
    )
  end
end
