class InstallmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!
  before_action :set_installment

  def edit
  end

  def update
    if @installment.update(installment_params)
      redirect_back fallback_location: clients_path, notice: "Parcela atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_installment
    @installment = Installment
      .joins(campaign_client: { campaign: :company })
      .where(companies: { id: current_user.company_id })
      .find(params[:id])
  end

  def installment_params
    params.require(:installment).permit(:amount, :status)
  end
end
