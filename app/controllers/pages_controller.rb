class PagesController < ApplicationController
  skip_before_action :check_onboarding

  def home
  end
end
