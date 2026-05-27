class WebhookController < ActionController::Base
  include Loggable

  # External webhook providers do not send Rails CSRF tokens.
  skip_forgery_protection
end
