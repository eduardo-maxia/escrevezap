class TranscriptionsController < ApplicationController
  layout "authenticated"
  before_action :authenticate_user!

  def index
    @transcriptions = current_user.waha_session
                        &.transcriptions
                        &.includes(:monitored_contact, :provider_usages)
                        &.recent
                        &.limit(100) || []
  end

  def show
    @transcription = current_user.waha_session
                       &.transcriptions
                       &.includes(:monitored_contact, :provider_usages, audio_attachment: :blob)
                       &.find_by(id: params[:id])
    redirect_to transcriptions_path unless @transcription
  end
end
