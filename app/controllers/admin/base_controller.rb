module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :require_admin!

    private

    def require_admin!
      unless current_user.admin?
        redirect_to authenticated_root_path, alert: t("admin.unauthorized")
      end
    end
  end
end
