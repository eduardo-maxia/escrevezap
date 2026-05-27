class PwaController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  protect_from_forgery except: :service_worker
  layout false

  def offline
  end

  def service_worker
    render template: "pwa/service_worker", content_type: "text/javascript"
  end

  def manifest
    render template: "pwa/manifest", content_type: "application/json"
  end
end
