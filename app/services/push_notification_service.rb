class PushNotificationService
  VAPID_SUBJECT = "mailto:suporte@cobrancaemdia.com.br"

  def self.notify(user, title:, body:, url: "/app")
    user.push_subscriptions.each do |sub|
      send_to(sub, title: title, body: body, url: url)
    end
  end

  def self.send_to(subscription, title:, body:, url: "/app")
    payload = JSON.generate({ title: title, body: body, url: url })

    WebPush.payload_send(
      message: payload,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: {
        subject:     VAPID_SUBJECT,
        public_key:  Rails.application.credentials.dig(:vapid, :public_key),
        private_key: Rails.application.credentials.dig(:vapid, :private_key)
      }
    )
  rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription
    subscription.destroy
  rescue => e
    Rails.logger.error "[PushNotificationService] #{e.class}: #{e.message}"
    Sentry.capture_exception(e)
  end
end
