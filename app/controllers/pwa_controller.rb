class PwaController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :check_onboarding, raise: false

  def offline
    render layout: "application"
  end
end
