class DashboardController < ApplicationController
  layout "authenticated"

  before_action :authenticate_user!

  def index
    @waha_session = current_user.waha_session
    @contacts     = @waha_session.monitored_contacts.order(:display_name) rescue []
    @month_count  = @waha_session.transcriptions.this_month.where.not(status: :failed).count rescue 0
    @total_count  = @waha_session.transcriptions.where.not(status: :failed).count rescue 0
    @top_contacts = top_contacts_this_month
  end

  private

  def top_contacts_this_month
    return [] unless @waha_session

    @waha_session.monitored_contacts
                 .joins(:transcriptions)
                 .where(transcriptions: { status: :completed })
                 .where("transcriptions.created_at >= ?", Time.current.beginning_of_month)
                 .group("monitored_contacts.id")
                 .order("COUNT(transcriptions.id) DESC")
                 .limit(5)
                 .select("monitored_contacts.*, COUNT(transcriptions.id) AS transcription_count")
  end
end
