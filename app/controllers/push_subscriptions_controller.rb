class PushSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    sub = current_user.push_subscriptions.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    sub.assign_attributes(p256dh: subscription_params[:p256dh], auth: subscription_params[:auth])

    if sub.save
      render json: { ok: true }, status: :created
    else
      render json: { ok: false }, status: :unprocessable_entity
    end
  end

  def destroy
    current_user.push_subscriptions
                .find_by(endpoint: params[:endpoint])
                &.destroy
    head :no_content
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, :p256dh, :auth)
  end
end
