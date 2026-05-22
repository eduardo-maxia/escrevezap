class ApplicationController < ActionController::Base
  include Loggable
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :check_onboarding

  def after_sign_in_path_for(resource)
    resource.onboarding_completed? ? authenticated_root_path : onboarding_step1_path
  end

  private

  def check_onboarding
    return unless user_signed_in?
    return if devise_controller?
    return if controller_name == "onboarding"
    return if current_user.onboarding_completed?

    redirect_to current_user.company.nil? ? onboarding_step1_path : onboarding_step2_path
  end

  def ensure_company!
    redirect_to onboarding_step1_path unless current_user&.company
  end

  def require_owner!
    redirect_to authenticated_root_path, alert: "Apenas o dono da empresa pode realizar esta ação." unless current_user.owner?
  end
end
