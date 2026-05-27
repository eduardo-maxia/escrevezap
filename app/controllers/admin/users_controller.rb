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
  end
end
