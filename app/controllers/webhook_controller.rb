class WebhookController < ActionController::Base
  include Loggable
  
  skip_before_action :verify_authenticity_token
end
