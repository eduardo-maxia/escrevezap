class ExternalEvents::WhatsappProcessor < ExternalEvents::Base
  # MIME types that indicate an audio message. Waha can return several variants.
  AUDIO_MIMETYPES = %w[
    audio/ogg audio/mpeg audio/mp4 audio/wav audio/webm audio/aac audio/opus
  ].freeze

  def process(worker_type: :waha)
    @data = parse_payload(worker_type)
    @external_event.update!(parsed_event: @data)

    return unless preprocess

    case @data[:event]
    when "session.status"
      process_session_status
    when "message", "message.any"
      process_incoming_message
    when "message.ack", "message.reaction"
      log_info "Evento #{@data[:event]} recebido — ignorado nesta versão"
    else
      log_warning "Evento desconhecido: #{@data[:event]}"
    end
  end

  private

  # ── Pre-processing: resolve the WahaSession from the session name ──────

  def preprocess
    log_info "Webhook: session=#{@data[:session]} event=#{@data[:event]}"

    @external_event.update!(event_type: @data[:event])

    @waha_session = WahaSession.find_by(session_name: @data[:session])
    if @waha_session.nil?
      log_warning "Nenhuma WahaSession encontrada para session=#{@data[:session]}"
      return false
    end

    true
  end

  # ── session.status ────────────────────────────────────────────────────

  def process_session_status
    status       = @data.dig(:payload, :status)
    waha_chat_id = @data.dig(:payload, :waha_chat_id)

    if status.present? && WahaSession.waha_statuses.key?(status)
      @waha_session.update!(waha_status: status)
    end

    if waha_chat_id.present? && @waha_session.waha_chat_id != waha_chat_id
      @waha_session.update!(waha_chat_id: waha_chat_id)
    end

    log_info "WahaSession #{@waha_session.id} → status=#{status} chat_id=#{waha_chat_id}"
  end

  # ── message / message.any ─────────────────────────────────────────────

  def process_incoming_message
    payload = @data[:payload]

    unless audio_message?(payload)
      log_info "Mensagem ignorada: não é áudio (hasMedia=#{payload[:hasMedia]})"
      return
    end

    from_me = payload[:fromMe]
    chat_id = payload[:from].to_s
    phone   = chat_id.split("@").first

    contact = resolve_or_auto_create_contact(phone, chat_id, from_me: from_me)
    return if contact.nil?

    # Respect per-contact direction preference
    if from_me && contact.incoming?
      log_info "Áudio próprio ignorado (contato configurado como incoming)"
      return
    end

    if !from_me && contact.outgoing?
      log_info "Áudio do contato ignorado (contato configurado como outgoing)"
      return
    end

    log_info "Criando transcription: contact=#{contact.id} message=#{payload[:message_id]}"

    direction = from_me ? "outgoing" : "incoming"

    transcription = Transcription.create!(
      monitored_contact: contact,
      waha_message_id:   payload[:message_id],
      direction:         direction,
      media_url:         payload.dig(:media, :url),
      status:            :processing
    )

    ActiveRecord.after_all_transactions_commit do
      TranscribeAudioJob.perform_later(transcription.id)
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  def audio_message?(payload)
    return false unless payload[:hasMedia]

    mimetype = payload.dig(:media, :mimetype).to_s
    mimetype.start_with?("audio/") || AUDIO_MIMETYPES.include?(mimetype)
  end

  # Look up the MonitoredContact by phone number or waha_chat_id.
  # Update waha_chat_id in the record if we discovered it here.
  def resolve_monitored_contact(phone, chat_id)
    contact = @waha_session.monitored_contacts.enabled
                           .find_by(phone_number: phone)
                           .presence ||
              @waha_session.monitored_contacts.enabled
                           .find_by(waha_chat_id: chat_id)

    if contact && contact.waha_chat_id.blank?
      contact.update_columns(waha_chat_id: chat_id)
    end

    contact
  end

  # Resolve an existing monitored contact or, when auto_transcribe is active,
  # create one on the fly so the standard pipeline can proceed unchanged.
  # Returns nil when the audio should be discarded.
  def resolve_or_auto_create_contact(phone, chat_id, from_me:)
    contact = resolve_monitored_contact(phone, chat_id)
    return contact if contact.present?

    # No existing contact — check whether the session has auto-transcribe enabled
    auto = @waha_session.auto_transcribe
    if auto == "never"
      log_info "Contato #{chat_id} não monitorado — descartando"
      return nil
    end

    # Early-exit for direction mismatches before touching the DB
    if auto == "incoming" && from_me
      log_info "Auto-transcribe (incoming): áudio próprio ignorado para #{chat_id}"
      return nil
    end
    if auto == "outgoing" && !from_me
      log_info "Auto-transcribe (outgoing): áudio de contato ignorado para #{chat_id}"
      return nil
    end

    log_info "Auto-transcribe (#{auto}): criando contato automático para #{chat_id}"

    contact = @waha_session.monitored_contacts.create!(
      phone_number:  phone,
      waha_chat_id:  chat_id,
      direction:     auto,
      enabled:       true
    )

    FetchMonitoredContactProfilePictureJob.perform_later(contact.id)
    contact
  end

  def parse_payload(worker_type)
    parser_class = case worker_type.to_sym
                   when :waha then ExternalEvents::WhatsappParsers::GowsParser
                   else            ExternalEvents::WhatsappParsers::GowsParser
                   end
    parser_class.new(@data).parse
  end
end
