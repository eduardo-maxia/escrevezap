class ApplicationController < ActionController::Base
  include Loggable

  before_action :set_locale
  before_action :check_onboarding

  def after_sign_in_path_for(resource)
    if resource.onboarding_completed?
      authenticated_root_path
    else
      onboarding_path
    end
  end

  private

  def check_onboarding
    return unless user_signed_in?
    return if onboarding_exempt?

    # Step 2: WhatsApp not yet connected
    unless current_user.onboarding_completed?
      redirect_to onboarding_path, notice: "Conecte seu WhatsApp para continuar."
      return
    end

    # Step 3: No contacts added yet and user hasn't dismissed the intro
    if !current_user.contacts_intro_dismissed? && on_step3_eligible_page?
      redirect_to onboarding_step3_path
    end
  end

  def onboarding_exempt?
    devise_controller? ||
      is_a?(PwaController) ||
      is_a?(PagesController) ||
      is_a?(OnboardingController) ||
      controller_name == "waha_sessions"
  end

  def set_locale
    I18n.locale = :"pt-BR"
  end

  def on_step3_eligible_page?
    # Only redirect to step 3 when user is landing on dashboard or root
    action_name == "index" && controller_name == "dashboard"
  end

  def route_not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
