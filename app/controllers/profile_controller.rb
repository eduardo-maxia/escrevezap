class ProfileController < ApplicationController
  layout "authenticated"
  before_action :authenticate_user!

  def show; end

  # PATCH /profile — name and/or avatar only
  def update
    if current_user.update(profile_params)
      redirect_to profile_path, notice: "Perfil atualizado."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  # PATCH /profile/update_email
  def update_email
    new_email = params[:user][:email].to_s.strip.downcase

    if new_email.blank?
      redirect_to profile_path, alert: "Informe o novo e-mail."
      return
    end

    if new_email == current_user.email
      redirect_to profile_path, alert: "Esse já é o seu e-mail atual."
      return
    end

    if current_user.update(email: new_email)
      # Devise reconfirmable will send a confirmation email automatically if enabled.
      # Without reconfirmable, the email is updated immediately.
      redirect_to profile_path, notice: "E-mail atualizado. Confirme no novo endereço se solicitado."
    else
      redirect_to profile_path, alert: current_user.errors[:email].first || "Não foi possível atualizar o e-mail."
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :avatar)
  end
end
