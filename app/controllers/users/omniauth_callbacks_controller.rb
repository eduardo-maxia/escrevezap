# Handles callbacks from OmniAuth providers (currently: Google).
#
# Devise routes /app/users/auth/:provider/callback here when configured via
# `devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }`.
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  def google_oauth2
    auth  = request.env["omniauth.auth"]
    user  = User.from_google(auth)

    if user.persisted?
      sign_in(user, event: :authentication)
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      redirect_to after_sign_in_path_for(user)
    else
      session["devise.google_data"] = auth.except("extra")
      redirect_to new_user_session_path, alert: user.errors.full_messages.join(", ")
    end
  end

  def failure
    redirect_to new_user_session_path,
                alert: "Não foi possível entrar com o Google. Tente novamente."
  end
end
