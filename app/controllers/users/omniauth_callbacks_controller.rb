class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth  = request.env["omniauth.auth"]
    @user = User.from_google(auth)

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      redirect_to new_user_session_path, alert: t("auth.oauth.failure")
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error(event: "oauth_failure", provider: "google", error: e.message)
    redirect_to new_user_session_path, alert: t("auth.oauth.failure")
  end

  def failure
    redirect_to new_user_session_path, alert: t("auth.oauth.failure")
  end
end
