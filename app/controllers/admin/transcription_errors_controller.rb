module Admin
  class TranscriptionErrorsController < Admin::BaseController
    include Pagy::Backend

    def index
      scope = TranscriptionError.includes(transcription: { monitored_contact: { waha_session: :user } })
                                .order(created_at: :desc)

      if params[:stage].present? && TranscriptionError::STAGES.include?(params[:stage])
        scope = scope.where(stage: params[:stage])
      end

      if params[:q].present?
        q = "%#{params[:q].strip.downcase}%"
        scope = scope.where("LOWER(transcription_errors.message) LIKE :q OR LOWER(transcription_errors.error_class) LIKE :q", q: q)
      end

      @pagy, @errors = pagy(scope, limit: 30)
      @stage_counts  = TranscriptionError.this_month.group(:stage).count
    end
  end
end
