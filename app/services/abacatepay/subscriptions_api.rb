module Abacatepay
  class SubscriptionsApi
    def initialize(api_request)
      @api = api_request
    end

    # Creates a subscription checkout and returns the parsed response.
    # Caller should check response["success"] and use response.dig("data", "url")
    # to redirect the user.
    def create(product_id:, customer_id: nil, external_id: nil, completion_url: nil, return_url: nil)
      body = {
        items: [ { id: product_id, quantity: 1 } ],
        methods: [ "CARD" ]
      }
      body[:customerId]    = customer_id    if customer_id.present?
      body[:externalId]    = external_id    if external_id.present?
      body[:completionUrl] = completion_url if completion_url.present?
      body[:returnUrl]     = return_url     if return_url.present?

      @api.post("/subscriptions/create", body)
    end

    # Cancels an active subscription immediately (irreversible).
    def cancel(id:)
      @api.post("/subscriptions/cancel", { id: id })
    end

    # Schedules a plan change for the next billing cycle.
    def change_plan(id:, product_id:, quantity: 1)
      @api.post("/subscriptions/change-plan", { id: id, productId: product_id, quantity: quantity })
    end
  end
end
