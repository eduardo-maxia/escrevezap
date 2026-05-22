class NotificationStatusChannel < ApplicationCable::Channel
  def subscribed
    notification = Notification.find_by(id: params[:notification_id])

    if notification && authorized?(notification)
      stream_from "notification_status_#{notification.id}"
    else
      reject
    end
  end

  def unsubscribed
    # auto cleanup
  end

  private

  def authorized?(notification)
    company = current_user&.company
    return false unless company

    notification.campaign_client.campaign.company_id == company.id
  rescue StandardError
    false
  end
end
