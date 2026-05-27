class OnboardingController < ApplicationController
  layout "auth"
  before_action :authenticate_user!
  before_action :redirect_if_completed, only: [:show]

  def show
    @waha_session = current_user.waha_session || current_user.build_waha_session

    # Session is already connected — ensure onboarding is marked complete and move on
    if @waha_session.working?
      current_user.complete_onboarding! unless current_user.onboarding_completed?
      redirect_to authenticated_root_path and return
    end

    if @waha_session.new_record? || @waha_session.pending?
      @waha_session.save! if @waha_session.new_record?
      begin
        @waha_session.connect!
      rescue => e
        flash.now[:alert] = "Não foi possível iniciar a sessão: #{e.message}"
      end
    end
  end

  def step3
    redirect_to authenticated_root_path if current_user.contacts_intro_dismissed?
  end

  def dismiss_contacts
    current_user.update!(contacts_intro_dismissed: true)
    redirect_to authenticated_root_path
  end

  private

  def redirect_if_completed
    redirect_to authenticated_root_path if current_user.onboarding_completed?
  end
end
