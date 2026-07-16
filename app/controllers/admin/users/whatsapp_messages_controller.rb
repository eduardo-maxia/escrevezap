module Admin
  module Users
    class WhatsappMessagesController < Admin::BaseController
      include Pagy::Backend

      def index
        @user = User.find(params[:user_id])
        normalized_phone = @user.uid.to_s.gsub(/\D/, "")

        scope = WhatsappMessage.where(user_id: @user.id)
        scope = scope.or(WhatsappMessage.where(phone: normalized_phone)) if normalized_phone.present?

        scope = scope.distinct.chronological
        @pagy, @messages = pagy(scope, limit: 120)
      end
    end
  end
end