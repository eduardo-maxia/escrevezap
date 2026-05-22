class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!
  layout "authenticated"

  def show; end

  # ── Empresa ────────────────────────────────────────────────────────
  def empresa
    @company = current_user.company
  end

  def update_empresa
    @company = current_user.company
    if @company.update(empresa_params)
      redirect_to settings_empresa_path, notice: "Dados da empresa atualizados."
    else
      render :empresa, status: :unprocessable_entity
    end
  end

  # ── Perfil ─────────────────────────────────────────────────────────
  def perfil; end

  def update_perfil
    if current_user.update_without_password(perfil_params)
      redirect_to settings_perfil_path, notice: "Perfil atualizado com sucesso."
    else
      render :perfil, status: :unprocessable_entity
    end
  end

  # ── Senha ──────────────────────────────────────────────────────────
  def senha; end

  def update_senha
    if current_user.update_with_password(senha_params)
      bypass_sign_in(current_user)
      redirect_to settings_senha_path, notice: "Senha alterada com sucesso."
    else
      render :senha, status: :unprocessable_entity
    end
  end

  # ── Cobrança (only when feature_campanhas = false) ─────────────────
  def cobranca
    @campaign = current_user.company.campaigns.first
    @chip     = current_user.company.chips.first
  end

  def update_cobranca
    @campaign = current_user.company.campaigns.first
    @chip     = current_user.company.chips.first
    if @campaign&.update(cobranca_params)
      redirect_to settings_cobranca_path, notice: "Configurações de cobrança atualizadas."
    else
      render :cobranca, status: :unprocessable_entity
    end
  end

  private

  def empresa_params
    params.require(:company).permit(:name)
  end

  def perfil_params
    params.require(:user).permit(:name, :email)
  end

  def senha_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def cobranca_params
    params.require(:campaign).permit(:start_time, :end_time, template: [:body])
  end
end
