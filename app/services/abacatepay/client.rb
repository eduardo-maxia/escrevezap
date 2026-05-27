module Abacatepay
  class Client
    BASE_URL = "https://api.abacatepay.com/v2".freeze

    def subscriptions
      @subscriptions ||= Abacatepay::SubscriptionsApi.new(api_request)
    end

    private

    def api_request
      @api_request ||= ApiRequest.new(BASE_URL, {
        "Authorization" => "Bearer #{api_key}"
      })
    end

    def api_key
      Rails.application.credentials.dig(:abacatepay, :api_key)
    end
  end
end
