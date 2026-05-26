class ChipDisconnectCheckJob < ApplicationJob
  queue_as :default

  def perform(chip_id)
    chip = Chip.find_by(id: chip_id)
    return if chip.nil? || chip.working?

    chip.company.users.each do |user|
      ChipMailer.disconnected(user, chip).deliver_later

      next unless user.notif_chip_disconnected?
      PushNotificationService.notify(
        user,
        title: "WhatsApp desconectado",
        body:  "O número #{chip.name} desconectou. Reconecte para não parar as cobranças.",
        url:   "/app/chips/#{chip.id}"
      )
    end
  end
end
