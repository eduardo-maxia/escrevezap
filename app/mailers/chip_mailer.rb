class ChipMailer < ApplicationMailer
  def disconnected(user, chip)
    @user = user
    @chip = chip

    mail(
      to: user.email,
      subject: "⚠️ Chip desconectado: #{chip.name}"
    )
  end
end
