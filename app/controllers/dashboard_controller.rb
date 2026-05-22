class DashboardController < ApplicationController
  before_action :authenticate_user!
  layout "authenticated"

  def index
    company = current_user.company

    if company
      @feature_campanhas = company.feature_campanhas?
      @clients_count    = company.clients.count
      @pending_count    = Installment
                            .pending
                            .joins(campaign_client: { campaign: :company })
                            .where(campaigns: { company_id: company.id })
                            .count
      @pending_amount   = Installment
                            .pending
                            .joins(campaign_client: { campaign: :company })
                            .where(campaigns: { company_id: company.id })
                            .sum(:amount)

      if @feature_campanhas
        @campaigns_count  = company.campaigns.count
        @active_campaigns = company.campaigns.active.count
        @chips_count      = company.chips.count
        @recent_campaigns = company.campaigns.includes(:chip).order(created_at: :desc).limit(5)
        @chips            = company.chips.order(:name)
        @critical_chips   = company.chips
                                    .joins(:campaigns)
                                    .where(campaigns: { status: "active" })
                                    .where.not(waha_status: "working")
                                    .distinct
                                    .order(:name)
      else
        @chip = company.chips.first

        # ── Simple-mode KPI extras ──────────────────────────────────────────
        today      = Date.today
        month_start = today.beginning_of_month
        month_end   = today.end_of_month

        base = Installment
                 .joins(campaign_client: { campaign: :company })
                 .where(campaigns: { company_id: company.id })

        @billing_month      = base.paid.where(due_date: month_start..month_end).sum(:amount)
        @pending_month_amount = base.pending.where(due_date: month_start..month_end).sum(:amount)

        # ── Chart data: last 6 months ────────────────────────────────────────
        months = 6.times.map { |i| (today - i.months).beginning_of_month }.reverse

        chart_start = months.first
        chart_end   = months.last.end_of_month

        paid_by_month = base
          .paid
          .where(due_date: chart_start..chart_end)
          .group("DATE_TRUNC('month', installments.due_date)")
          .sum(:amount)
          .transform_keys { |k| k.to_date.beginning_of_month }

        pending_by_month = base
          .pending
          .where(due_date: chart_start..chart_end)
          .group("DATE_TRUNC('month', installments.due_date)")
          .sum(:amount)
          .transform_keys { |k| k.to_date.beginning_of_month }

        clients_by_month = company.clients
          .where(created_at: chart_start.beginning_of_day..chart_end.end_of_day)
          .group("DATE_TRUNC('month', created_at)")
          .count
          .transform_keys { |k| k.to_date.beginning_of_month }

        @chart_data = {
          labels:       months.map { |m| I18n.l(m, format: "%b %y").capitalize },
          receita:      months.map { |m| (paid_by_month[m] || 0).to_f },
          clientes:     months.map { |m| clients_by_month[m] || 0 },
          inadimplencia: months.map { |m| (pending_by_month[m] || 0).to_f }
        }
      end
    else
      @feature_campanhas = false
      @campaigns_count = @active_campaigns = @clients_count = @chips_count = 0
      @pending_count   = 0
      @pending_amount  = 0
      @billing_month   = 0
      @pending_month_amount = 0
      @chart_data      = { labels: [], receita: [], clientes: [], inadimplencia: [] }
      @recent_campaigns = []
      @chips            = []
      @critical_chips   = []
    end
  end
end
