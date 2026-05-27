class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def not_found
    respond_to do |format|
      format.html do
        if user_signed_in?
          redirect_to authenticated_root_path
        else
          redirect_to root_path
        end
      end
      format.any { head :not_found }
    end
  end
end
