class UsageMailer < ApplicationMailer
  def limit_reached(user)
    @user = user
    mail(
      to: @user.email,
      subject: "⚠️ Você atingiu seu limite de transcrições do EscreveZap"
    )
  end
end
