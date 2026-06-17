module Admin
  class UsersController < Admin::BaseController
    include Pagy::Backend

    def index
      scope = User.includes(:subscription, :waha_session).order(created_at: :desc)

      if params[:q].present?
        q = "%#{params[:q].strip.downcase}%"
        scope = scope.where("LOWER(users.email) LIKE :q OR LOWER(users.name) LIKE :q", q: q)
      end

      if params[:plan].present? && User.plans.key?(params[:plan])
        scope = scope.where(plan: params[:plan])
      end

      @pagy, @users = pagy(scope, limit: 30)
    end

    def show
      @user = User.includes(:subscription, :waha_session).find(params[:id])
      @waha_session = @user.waha_session

      if @waha_session
        @total_transcriptions = @waha_session.transcriptions.count
        @successful_transcriptions = @waha_session.transcriptions.completed.count
        @failed_transcriptions = @waha_session.transcriptions.failed.count

        scope = @waha_session.transcriptions.order(created_at: :desc)
      else
        @total_transcriptions = 0
        @successful_transcriptions = 0
        @failed_transcriptions = 0
        scope = Transcription.none
      end

      @pagy, @transcriptions = pagy(scope, limit: 30)
    end
  end
end
