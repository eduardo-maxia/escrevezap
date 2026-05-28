class TranscribeAudioJob < ApplicationJob
  queue_as :default
  DEFAULT_AUDIO_EXTENSION = ".ogg".freeze

  # Transcrições com menos caracteres que este limiar não recebem resumo/formatação AI.
  # Precisa de pelo menos ~3-4 frases para um resumo agregar valor.
  AI_MIN_CHARS = 350

  # Selects which STT engine to use. Defaults to deepgram.
  # Set credentials[:transcription_engine] = "gpt-4o-transcribe" to switch to OpenAI.
  TRANSCRIPTION_ENGINE = (Rails.application.credentials[:transcription_engine] || "deepgram").freeze

  # ── Prompts ────────────────────────────────────────────────────────────

  # "Polished" — texto refinado com resumo e formatação completa.
  AI_PROMPT_POLISHED = <<~PROMPT.freeze
    Você é um assistente especializado em MELHORAR transcrições de áudio do WhatsApp.

    Sua tarefa é pegar uma transcrição falada e transformá-la em uma mensagem de WhatsApp clara, organizada e agradável de ler.

    OBJETIVO:
    Manter exatamente o mesmo significado do áudio, mas melhorar bastante a apresentação do texto.

    REGRAS IMPORTANTES:

    - NÃO mude o significado
    - NÃO invente informações
    - NÃO resuma
    - NÃO transforme em algo corporativo
    - Preserve a intenção original
    - Preserve o tom informal quando fizer sentido

    VOCÊ DEVE:
    - melhorar clareza
    - organizar frases
    - corrigir gramática
    - adicionar pontuação
    - quebrar em parágrafos
    - remover vícios de fala excessivos
    - deixar o texto mais agradável de ler
    - reorganizar frases quando necessário

    O resultado deve parecer:

    "essa pessoa falou isso de forma clara no WhatsApp"

    EXEMPLO:

    ENTRADA:
    "aí a gente ainda pode botar uma opção extra que é passar em uma ia depois de transcrever pra melhorar o texto voce manda o audio falando assim de qualquer jeito"

    SAÍDA ESPERADA:
    "Aí a gente ainda pode colocar uma opção extra, que seria passar o texto por uma IA depois da transcrição, pra dar uma melhorada, né?

    Você manda o áudio do seu jeito, normalmente, e depois a IA organiza tudo, deixando o texto mais claro e bonitinho."

    Dado o texto transcrito abaixo, retorne um JSON com duas chaves:
    - "summary": Um resumo em UMA frase curta (máximo 120 caracteres) do ponto central
      da mensagem. O resumo DEVE ser substancialmente mais curto que o texto original.
      Se o texto for curto (menos de 3 frases distintas) ou se não for possível resumir
      sem perder o essencial, retorne null.
    - "full_formatted": A transcrição formatada de forma legível, corrigindo pontuação,
      paragrafando naturalmente e destacando termos importantes com *negrito*.
    Responda SOMENTE com o JSON válido, sem markdown, sem comentários.
  PROMPT

  # "Faithful" — o mais próximo do que foi dito, mínima intervenção AI.
  AI_PROMPT_FAITHFUL = <<~PROMPT.freeze
    Você é um assistente especializado em LIMPAR transcrições de áudio do WhatsApp.

    Sua tarefa é transformar uma transcrição falada em um texto mais legível, MAS preservando ao máximo o jeito original da pessoa falar.

    OBJETIVO:
    O texto deve parecer a mesma pessoa falando, só que um pouco mais organizado.

    REGRAS IMPORTANTES:

    - NÃO reescreva o conteúdo de forma profissional
    - NÃO mude o tom da pessoa
    - NÃO resuma
    - NÃO adicione informações
    - NÃO invente contexto
    - NÃO transforme em texto corporativo
    - NÃO deixe “bonito demais”
    - Preserve informalidade e espontaneidade
    - Preserve gírias e jeito de falar
    - Preserve hesitações quando fizer sentido
    - Corrija apenas o necessário para leitura ficar fluida

    VOCÊ PODE:
    - corrigir pontuação
    - separar parágrafos
    - remover repetições excessivas
    - melhorar levemente gramática
    - corrigir palavras claramente erradas da transcrição
    - deixar a leitura mais natural

    IMPORTANTE:
    Se a pessoa falou de forma bagunçada, mantenha um pouco dessa naturalidade.

    EXEMPLO:

    ENTRADA:
    "aí a gente ainda pode botar uma opção extra que é passar numa ia depois de transcrever pra melhorar o texto né voce manda o audio de qualquer jeito"

    SAÍDA ESPERADA:
    "Aí a gente ainda pode botar uma opção extra, que é passar numa IA depois de transcrever, pra dar uma melhorada no texto, né?

    Você manda o áudio de qualquer jeito mesmo, normal..."

    Dado o texto transcrito abaixo, retorne um JSON com duas chaves:
    - "summary": null
    - "full_formatted": O texto com erros óbvios de reconhecimento de voz corrigidos
      e pontuação básica adicionada. Preserve absolutamente o vocabulário, as expressões,
      o ritmo e o estilo de fala original. Não reformule, não reescreva, não resuma.
    Responda SOMENTE com o JSON válido, sem markdown, sem comentários.
  PROMPT

  def perform(transcription_id)
    transcription   = Transcription.find(transcription_id)
    contact         = transcription.monitored_contact
    waha_session    = contact.waha_session
    user            = waha_session.user

    # Guard: session must be connected
    unless waha_session.working?
      Rails.logger.warn "[TranscribeAudioJob] WahaSession #{waha_session.id} not working — skipping"
      return
    end

    # Guard: monthly limit
    if user.transcription_limit_reached?
      Rails.logger.info "[TranscribeAudioJob] Limite mensal atingido para user #{user.id} — skipping"
      send_limit_reached_notice(waha_session, contact)
      fail_transcription!(transcription, "Limite mensal de transcrições atingido")
      return
    end

    process_transcription(transcription, waha_session, contact, user)
  end

  private

  def process_transcription(transcription, waha_session, contact, user)
    media_url = transcription.media_url

    unless media_url.present?
      fail_transcription!(transcription, "URL de mídia ausente na mensagem")
      return
    end

    chat_id     = contact.resolve_waha_chat_id
    reply_to_id = transcription.waha_message_id
    placeholder_message_id = nil

    # 0. Mark chat as read + send immediate progress feedback
    waha_session.waha_client.chats.read_messages(chat_id: chat_id)
    placeholder_response   = waha_session.waha_client.messaging.send_text(
      chat_id:  chat_id,
      text:     "_⏳ Transcrevendo com o EscreveZap! Aguarde um instante..._",
      reply_to: reply_to_id
    )
    placeholder_message_id = placeholder_response["id"]

    # 1. Download the audio binary from Waha
    audio_data = waha_session.waha_client.messaging.download_media_from_url(media_url: media_url)
    attach_audio(transcription, audio_data, media_url)

    # 2. Write to a temp file and transcribe
    transcriber = nil
    transcript = Tempfile.create(["wt_audio_#{transcription.id}", ".ogg"], binmode: true) do |file|
      file.write(audio_data)
      file.flush
      transcriber = build_transcriber(file.path)
      text = transcriber.speech_to_text
      transcription.update!(audio_duration: transcriber.duration) if transcriber.duration
      text
    end

    if transcript.blank?
      fail_transcription!(transcription, "#{TRANSCRIPTION_ENGINE} retornou transcrição vazia")
      return
    end

    # Track STT provider cost
    track_transcription_usage(transcription, transcriber)

    # 3. AI formatting (Pro plan only, minimum transcript length required)
    ai_token_count = nil
    if user.pro? && transcript.length >= AI_MIN_CHARS
      summary, full_formatted, ai_token_count = ai_format(transcript, user)
    end
    track_openai_usage(transcription, ai_token_count) if ai_token_count

    # 4. Update the transcription record
    transcription.update!(
      transcript:     transcript,
      summary:        summary,
      full_formatted: full_formatted,
      status:         :completed
    )

    # 5. Edit the placeholder with the final transcription
    reply_text = transcription.reply_text(user)
    waha_session.waha_client.messaging.edit_message(
      chat_id:    chat_id,
      message_id: placeholder_message_id,
      text:       reply_text
    )
    transcription.update!(reply_message_id: placeholder_message_id)

    # 6. Track usage event (async, non-critical)
    metadata = { transcription_id: transcription.id, duration: transcriber&.duration, plan: user.plan }
    TrackUsageJob.perform_later(user_id: user.id, event_type: UsageEvent::TRANSCRIPTION_COMPLETED, metadata: metadata)
    if ai_token_count
      TrackUsageJob.perform_later(user_id: user.id, event_type: UsageEvent::AI_FORMAT_COMPLETED, metadata: { transcription_id: transcription.id, tokens: ai_token_count })
    end
  rescue => e
    Rails.logger.error "[TranscribeAudioJob] Erro ao processar transcription #{transcription.id}: #{e.message}"
    if placeholder_message_id
      begin
        waha_session.waha_client.messaging.edit_message(
          chat_id:    chat_id,
          message_id: placeholder_message_id,
          text:       "❌ _Não foi possível transcrever este áudio. Tente novamente._"
        )
      rescue => edit_error
        Rails.logger.warn "[TranscribeAudioJob] Falha ao editar placeholder de erro: #{edit_error.message}"
      end
    end
    fail_transcription!(transcription, e.message)
    raise e
  end

  # ── AI Formatting ──────────────────────────────────────────────────────

  # Returns [summary, full_formatted, total_tokens]
  def ai_format(transcript, user)
    prompt = user.faithful? ? AI_PROMPT_FAITHFUL : AI_PROMPT_POLISHED
    response = Llm::Client.new(model: "gpt-5.4-mini")
                          # Joga a verbosity e o thinking lá embaixo
                          .with_params(reasoning: {effort: 'low'}, text: {verbosity: 'low'})
                          .with_instructions(prompt)
                          .add_message(role: "user", content: transcript)
                          .complete

    result      = JSON.parse(response.content, symbolize_names: true)
    token_count = response.respond_to?(:usage) ? response.usage&.total_tokens : nil
    [result[:summary], result[:full_formatted], token_count]
  rescue JSON::ParserError, KeyError => e
    Rails.logger.warn "[TranscribeAudioJob] AI format parse error: #{e.message}"
    [nil, nil, nil]
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] AI format failed: #{e.message}"
    [nil, nil, nil]
  end

  # ── Engine factory ────────────────────────────────────────────────────

  def build_transcriber(file_path)
    case TRANSCRIPTION_ENGINE
    when "gpt-4o-transcribe"
      GptTranscribe.new(file_path)
    else
      Deepgram.new(file_path)
    end
  end

  # ── Provider cost tracking ─────────────────────────────────────────────

  def track_transcription_usage(transcription, transcriber)
    case transcriber
    when Deepgram
      track_deepgram_usage(transcription, transcriber.duration)
    when GptTranscribe
      track_gpt_transcribe_usage(transcription, transcriber.total_tokens, transcriber.duration)
    end
  end

  def track_deepgram_usage(transcription, duration_seconds)
    return unless duration_seconds.present?

    ProviderUsage.create!(
      transcription: transcription,
      provider:      "deepgram",
      units:         duration_seconds.to_f,
      unit_type:     "seconds",
      cost_usd:      duration_seconds.to_f * ProviderUsage::DEEPGRAM_USD_PER_SECOND
    )
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] Failed to track Deepgram usage: #{e.message}"
  end

  def track_openai_usage(transcription, token_count)
    return unless token_count.present?

    ProviderUsage.create!(
      transcription: transcription,
      provider:      "openai",
      units:         token_count.to_f,
      unit_type:     "tokens",
      cost_usd:      token_count.to_f * ProviderUsage::OPENAI_USD_PER_TOKEN
    )
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] Failed to track OpenAI usage: #{e.message}"
  end

  def track_gpt_transcribe_usage(transcription, token_count, duration_seconds)
    if token_count.present?
      ProviderUsage.create!(
        transcription: transcription,
        provider:      "openai-transcribe",
        units:         token_count.to_f,
        unit_type:     "tokens",
        cost_usd:      token_count.to_f * ProviderUsage::GPT_TRANSCRIBE_USD_PER_TOKEN
      )
    elsif duration_seconds.present?
      ProviderUsage.create!(
        transcription: transcription,
        provider:      "openai-transcribe",
        units:         duration_seconds.to_f,
        unit_type:     "seconds",
        cost_usd:      duration_seconds.to_f * ProviderUsage::GPT_TRANSCRIBE_USD_PER_SECOND
      )
    end
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] Failed to track gpt-4o-transcribe usage: #{e.message}"
  end

  def attach_audio(transcription, audio_data, media_url)
    extension = begin
      File.extname(URI.parse(media_url).path).presence || DEFAULT_AUDIO_EXTENSION
    rescue URI::InvalidURIError
      DEFAULT_AUDIO_EXTENSION
    end

    filename = "transcription-#{transcription.id}#{extension}"
    transcription.audio.attach(io: StringIO.new(audio_data), filename: filename)
  rescue StandardError => e
    Rails.logger.warn "[TranscribeAudioJob] Failed to attach audio for transcription #{transcription.id}: #{e.class}: #{e.message}"
  end

  def fail_transcription!(transcription, message)
    transcription.update!(status: :failed, error_message: message)
  end
end
