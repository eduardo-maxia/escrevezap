module Admin
  class TranscriptionsController < Admin::BaseController
    include Pagy::Backend

    def index
      scope = Transcription.includes(monitored_contact: { waha_session: :user })
                           .order(created_at: :desc)

      if params[:status].present? && Transcription.statuses.key?(params[:status])
        scope = scope.where(status: params[:status])
      end

      if params[:q].present?
        q = "%#{params[:q].strip.downcase}%"
        scope = scope.where("LOWER(transcriptions.transcript) LIKE :q OR LOWER(transcriptions.summary) LIKE :q", q: q)
      end

      @pagy, @transcriptions = pagy(scope, limit: 30)
    end

    def show
      @transcription = Transcription.includes(:monitored_contact, :provider_usages, :transcription_errors, monitored_contact: { waha_session: :user }).find(params[:id])
    end
  end
end
