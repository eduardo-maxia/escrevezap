module Waha
  class Service
    DEFAULT_SESSION = "default"

    def initialize(session: DEFAULT_SESSION)
      @session = session
      load_api_request_instance
    end

    private

    def load_api_request_instance
      @api_request = ApiRequest.new(Rails.application.credentials.dig(:waha, :base_url), {
        "X-Api-Key" => Rails.application.credentials.dig(:waha, :api_key)
      })
    end
  end
end
