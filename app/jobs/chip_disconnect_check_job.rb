class ChipDisconnectCheckJob < ApplicationJob
  queue_as :default

  def perform(chip_id)
    chip = Chip.find_by(id: chip_id)
    return if chip.nil? || chip.working?

    chip.company.users.each do |user|
      ChipMailer.disconnected(user, chip).deliver_later
    end
  end
end
