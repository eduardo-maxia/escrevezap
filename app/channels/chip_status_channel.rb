class ChipStatusChannel < ApplicationCable::Channel
  def subscribed
    chip = Chip.find_by(id: params[:chip_id])

    if chip && authorized?(chip)
      stream_from "chip_status_#{chip.id}"
    else
      reject
    end
  end

  def unsubscribed
    # auto cleanup
  end

  private

  def authorized?(chip)
    current_user&.company_id == chip.company_id
  rescue StandardError
    false
  end
end
