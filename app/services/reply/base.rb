module Reply
  class Base
    include Reply::Router
    include Reply::Onboarding
    include Reply::Connectivity
    include Reply::Billing

    def initialize(from:, display_name: nil)
      @display_name = display_name
      @from = from # e.g. "5585999999999@c.us"
      @phone = from.split("@").first

      # Check if the user already exists in the database
      @session = WahaSession.find_or_initialize_by(waha_chat_id: from)

      if @session.new_record?
        @user = User.create!(
          name: display_name.presence || "Novo usuário",
          provider: :phone,
          uid: @phone
        )
        @session.user = @user
        @session.save!
      else
        @user = @session.user
      end

      @current_conversation_state = @user.conversation_state || {}
      @last_reply = @current_conversation_state.dig("last_reply_at")&.to_datetime

      if @last_reply && @last_reply < 2.hours.ago
        @current_conversation_state = { "stage" => "initial" }
      end
    end

    # ── Meta Service Helpers ────────────────────────────────────────────────

    def send_message(message:)
      Meta::Service.new(recipient: @phone).send_message(message)
    end

    def send_list_message(body_text:, button_text:, sections:, header_text: nil, footer_text: nil)
      Meta::Service.new(recipient: @phone).send_list_message(
        body_text: body_text,
        button_text: button_text,
        sections: sections,
        header_text: header_text,
        footer_text: footer_text
      )
    end

    def send_contact(name:, phone:)
      Meta::Service.new(recipient: @phone).send_contact(name: name, phone: phone)
    end

    def send_cta_url_message(body_text:, button_text:, url:, header_text: nil, footer_text: nil)
      Meta::Service.new(recipient: @phone).send_cta_url_message(
        body_text: body_text,
        button_text: button_text,
        url: url,
        header_text: header_text,
        footer_text: footer_text
      )
    end
  end
end
