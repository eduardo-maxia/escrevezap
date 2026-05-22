class PagesController < ApplicationController
  layout "landing"
  skip_before_action :check_onboarding

  def home
  end
end
