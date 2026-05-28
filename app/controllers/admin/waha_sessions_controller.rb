module Admin
  class WahaSessionsController < Admin::BaseController
    before_action :set_waha_session

    def edit; end

    def update
      if @waha_session.update(waha_session_params)
        redirect_to admin_users_path, notice: "Sessão atualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_waha_session
      @waha_session = WahaSession.find(params[:id])
    end

    def waha_session_params
      params.require(:waha_session).permit(:auto_transcribe)
    end
  end
end
