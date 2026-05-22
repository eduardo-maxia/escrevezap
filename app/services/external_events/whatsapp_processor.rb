class ExternalEvents::WhatsappProcessor < ExternalEvents::Base
  # This processor handles WhatsApp webhooks from different providers (NOWEB/WAHA, Meta)
  # It uses specific parsers to normalize payloads into a standard format before processing

  def process(worker_type: :waha)
    @data = parse_payload(worker_type)
    @external_event.update!(parsed_event: @data)

    # Primeiro, vamos extrair os dados base e fazer pre processamento do evento
    return unless preprocess # Returna false se o webhook deve ser ignorado

    case @data[:event]
    when 'session.status'
      process_session_status
    when 'message.ack'
      process_ack_message
    when 'message.reaction'
      process_message_reaction
    else
      log_warning "Evento desconhecido: #{@data[:event]}"
      raise "Evento desconhecido: #{@data[:event]}"
    end
  end

  def process_session_status
    waha_status = @data[:payload][:status]
    waha_chat_id = @data[:payload][:waha_chat_id]

    @chip.update!(waha_status: waha_status)
    if waha_chat_id.present? && @chip.waha_chat_id != waha_chat_id
      @chip.update!(waha_chat_id: waha_chat_id)
    end
  end

  def process_message_reaction
    log_info "A mensagem é do tipo reaction"
    # Se a reação não for: 👍, dropa
    unless @data.dig(:payload, :body) == "👍"
      log_info "Reação ignorada: #{@data.dig(:payload, :body)}"
      return
    end

    chat_id = @data.dig(:payload, :from)
    log_info "Chat ID da reação: #{chat_id}"

    # TODO: Se for, temos que buscar a mensagem original e descobrir se é uma imagem. Se for, guardamos ela como comprovante.
    # 1 - Vamos ter que achar o campaign_client através do chat_id e do chip
    possible_campaign_clients = CampaignClient.joins(:client)
      .where(campaign: @chip.campaigns)
      .where(clients: { waha_chat_id: chat_id })

    # Se tiver mais de um já mata.
    if possible_campaign_clients.count > 1
      log_info "Mais de um campaign_client encontrado para chat_id #{chat_id} e chip_id #{@chip.id}"
      return
    end

    campaign_client = possible_campaign_clients.first
    if campaign_client.nil?
      log_info "Nenhum campaign_client encontrado para chat_id #{chat_id} e chip_id #{@chip.id}"
      return
    end

    # 2 - Agora vamos caçar a mensagem original que recebeu a reação
    message_id = @data.dig(:payload, :reply_to_id)
    response = Waha::Client.new(session: @chip.waha_session).messaging.get_message(chat_id: chat_id, message_id: message_id)
    
    is_image = response["hasMedia"] && response.dig("media", "mimetype")&.start_with?("image/")
    unless is_image
      log_info "Mensagem original não é uma imagem, ignorando reação. message_id: #{message_id}, type: #{response["type"]}"
      return
    end

    # 3 - Se for imagem, baixa ela e salva como comprovante da primeira parcela que esteja em aberto do campaign_client
    installment = campaign_client.installments.pending.first
    unless installment.present?
      log_info "Nenhuma parcela pendente encontrada para o campaign_client #{campaign_client.id}, ignorando reação."
      return
    end

    image_url = response.dig("media", "url")
    if image_url.blank?
      log_info "URL da imagem não encontrada na mensagem original, ignorando reação. message_id: #{message_id}"
      return
    end

    # Baixa a imagem e salva como comprovante
    begin
      downloaded_image = Waha::Client.new(session: @chip.waha_session).messaging.download_media_from_url(media_url: image_url) # This is raw binary data

      io = StringIO.new(downloaded_image)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: "comprovante_#{installment.id}.#{response.dig("media", "mimetype").split("/").last}",
        content_type: response.dig("media", "mimetype")
      )

      installment.update!(status: :paid, proof_image: blob)
      log_info "Parcela #{installment.id} marcada como paga com comprovante da reação 👍"
    rescue => e
      log_error "Erro ao baixar ou salvar a imagem do comprovante: #{e.message}"
    end
  end

  def preprocess
    log_info "Recebendo webhook do WhatsApp, session: #{@data[:session]}, event: #{@data[:event]}"

    @external_event.update!(event_type: @data[:event])

    @chip = Chip.waha.find_by(waha_session: @data[:session])
    if @chip.nil?
      log_warning "Não foi encontrado um chip para a sessão #{@data[:session]}"
      return false
    end

    return true
  end

  private

  def process_ack_message
    log_info "A mensagem é do tipo ack"

    @message_id = @data[:payload][:message_id]
    ack_status = @data[:payload][:ack]

    message = Notification.message.find_by(external_id: @message_id, sender: @chip)
    if message.present?
      message.set_ack(ack_status)
      # message.update!(created_at: @data[:payload][:created_at]) if @data[:payload][:created_at].present?
    else
      log_error "Mensagem não encontrada: #{@message_id}"
      # Se o chat nem existe, não precisa nem dar retry.
      return unless @data[:payload][:fromMe] && @data[:payload][:from].present?

      log_error "Chat ID: #{@data[:payload][:from]}"
      client_exists = Client.where(waha_chat_id: @data[:payload][:from]).joins(:campaign_clients).where(campaign_clients: { campaign: @chip.campaigns }).exists?
      
      return unless client_exists

      # Se existe pelo menos o chat, pode tentar de novo
      raise ScheduleRetryError, "Mensagem não encontrada: #{@message_id}"
    end
  end

  def format_waha_chat_id(waha_chat_id)
    return nil unless waha_chat_id.present?

    # waha_chat_id: 5521936181803@c.us
    # formatted: (21) 93618-1803
    phone_number = waha_chat_id.split('@').first # "5521936181803"
    country_code = phone_number[0..1] # "55"
    area_code = phone_number[2..3]    # "21"
    number = phone_number[4..-1]      # "936181803"
    formatted_number = if number.length == 9
                         "#{number[0]}#{number[1..4]}-#{number[5..8]}"
                       else
                         "#{number[0..3]}-#{number[4..7]}"
                       end
    "(#{area_code}) #{formatted_number}"
  end

  def parse_payload(worker_type)
    # A ideia aqui é transformar todos os payloads em um formato padrão
    # O formato padrão vai ser definido para cada tipo de evento
    
    # Para eventos do tipo message, o formato padrão será:
    # {
    #   event: 'message',
    #   session: 'session_id',
    #   payload: {
    #     from: 'waha_chat_id', # Chat id do contato
    #     fromMe: true/false,
    #     message_id: 'message_id',
    #     created_at: Time object,
    #     body: 'message body',
    #     hasMedia: true/false,
    #     media: {
    #       url: 'media url' (opcional, pode ser nil para Meta),
    #       media_id: 'media_id' (para Meta),
    #       mimetype: 'media mimetype',
    #       filename: 'media filename'
    #     }
    #   }
    # }

    # Para eventos do tipo message.ack, o formato padrão será:
    # {
    #   event: 'message.ack',
    #   session: 'session_id',
    #   payload: {
    #     message_id: 'message_id',
    #     ack: 'ack status (em lowercase)'
    #   }
    # }

    # Para eventos do tipo session.status, o formato padrão será:
    # {
    #   event: 'session.status',
    #   session: 'session_id',
    #   payload: {
    #     status: 'status string (em lowercase)',
    #     waha_chat_id: 'waha_chat_id' (opcional)
    #   }
    # }

    parser = 
      case worker_type
      when :waha
        # Investiga o environment do evento
        case @data.dig(:environment, :engine)
        when 'GOWS'
          ExternalEvents::WhatsappParsers::GowsParser.new(@data)
        else
          raise "Engine não suportada: #{@data.dig(:environment, :engine)}"
        end
      else
        raise "Worker type não suportado: #{worker_type}"
      end

    parser.parse
  end
end
