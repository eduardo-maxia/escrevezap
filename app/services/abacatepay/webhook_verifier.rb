module Abacatepay
  # Validates webhook authenticity using two mechanisms:
  #   1. Query param `webhookSecret` (configured in AbacatePay dashboard)
  #   2. HMAC-SHA256 signature in X-Webhook-Signature header (AbacatePay public key)
  class WebhookVerifier
    # AbacatePay's public HMAC key (documented at docs.abacatepay.com/pages/webhooks/security)
    ABACATEPAY_PUBLIC_KEY = "t9dXRhHHo3yDEj5pVDYz0frf7q6bMKyMRmxxCPIPp3RCplBfXRxqlC6ZpiW" \
                            "mOqj4L63qEaeUOtrCI8P0VMUgo6iIga2ri9ogaHFs0WIIywSMg0q7RmBfybe" \
                            "1E5XJcfC4IW3alNqym0tXoAKkzvfEjZxV6bE0oG2zJrNNYmUCKZyV0KZ3JS" \
                            "8Votf9EAWWYdiDkMkpbMdPggfh1EqHlVkMiTady6jOR3hyzGEHrIz2Ret0xH" \
                            "KMbiqkr9HS1JhNHDX9".freeze

    def self.valid_secret?(params)
      expected = Rails.application.credentials.dig(:abacatepay, :webhook_secret).to_s
      # If not configured in credentials, skip this check.
      return true if expected.blank?

      ActiveSupport::SecurityUtils.secure_compare(expected, params[:webhookSecret].to_s)
    end

    def self.valid_signature?(raw_body, signature_header)
      return true if signature_header.blank? # Signature not present — skip (dev/sandbox)

      expected = Base64.strict_encode64(
        OpenSSL::HMAC.digest("sha256", ABACATEPAY_PUBLIC_KEY, raw_body)
      )
      ActiveSupport::SecurityUtils.secure_compare(expected, signature_header.to_s)
    end
  end
end
