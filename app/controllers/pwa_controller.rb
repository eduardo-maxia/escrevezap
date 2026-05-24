class PwaController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :check_onboarding, raise: false

  def offline
    render layout: "application"
  end
end
