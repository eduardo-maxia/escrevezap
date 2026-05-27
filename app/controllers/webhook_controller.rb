class WebhookController < ActionController::Base
  include Loggable

  protect_from_forgery with: :null_session
end
