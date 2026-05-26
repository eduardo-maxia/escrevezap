class ApplicationController < ActionController::Base
  include Loggable
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  before_action :redirect_www
  before_action :check_onboarding

  # Never 404 — bad record IDs fall back to a sensible page.
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::RoutingError, with: :handle_not_found

  def after_sign_in_path_for(resource)
    resource.onboarding_completed? ? authenticated_root_path : onboarding_step1_path
  end

  # After Devise sign-out, send the user back to the login page (not the
  # marketing home), so they can immediately log back in.
  def after_sign_out_path_for(_resource_or_scope)
    new_user_session_path
  end

  # Catch-all action wired from the routes file — used when no route matches.
  def route_not_found
    handle_not_found
  end

  private

  def redirect_www
    return unless request.host.start_with?("www.")
    redirect_to "https://cobrancaemdia.com.br#{request.fullpath}",
                status: :moved_permanently, allow_other_host: true
  end

  def handle_not_found(_exception = nil)
    target = user_signed_in? ? authenticated_root_path : new_user_session_path
    respond_to do |format|
      format.html { redirect_to target, alert: "Página não encontrada." }
      format.json { render json: { error: "not_found" }, status: :not_found }
      format.any  { redirect_to target, alert: "Página não encontrada." }
    end
  end

  def check_onboarding
    return unless user_signed_in?
    return if devise_controller?
    return if controller_name == "onboarding"
    return if current_user.onboarding_completed?

    redirect_to current_user.company.nil? ? onboarding_step1_path : onboarding_step2_path
  end

  def require_campaigns!
    return if current_user&.company&.feature_campanhas?
    redirect_to authenticated_root_path, alert: "Funcionalidade de campanhas não disponível nesta conta."
  end

  def ensure_company!
    redirect_to onboarding_step1_path unless current_user&.company
  end

  def require_owner!
    redirect_to authenticated_root_path, alert: "Apenas o dono da empresa pode realizar esta ação." unless current_user.owner?
  end
end
