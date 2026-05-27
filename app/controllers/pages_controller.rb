class PagesController < ApplicationController
  layout :page_layout

  # Anti-spam:
  #   - hard limit on file size (defense in depth — Rack rejects larger uploads anyway)
  #   - rate limit per IP (Rails 8 RateLimiting backed by SolidCache)
  #   - server-side rejection if Deepgram reports > MAX_DURATION
  MAX_UPLOAD_BYTES = 1.megabyte
  MAX_DURATION     = 12.0   # client caps at 10s; allow a small slack
  AI_MIN_CHARS     = 80     # lower than the job's threshold so demos still get a summary

  AI_PROMPT_DEMO = <<~PROMPT.freeze
    Você é um assistente que processa transcrições de áudios do WhatsApp.
    Dado o texto transcrito abaixo, retorne um JSON com duas chaves:
    - "summary": Um resumo conciso em até 2 frases do que foi dito. Se o texto for muito curto, retorne null.
    - "full_formatted": A transcrição formatada de forma legível, corrigindo pontuação,
      paragrafando naturalmente e destacando termos importantes com *negrito*.
    Responda SOMENTE com o JSON válido, sem markdown, sem comentários.
  PROMPT

  rate_limit to: 5,  within: 1.minute, by: -> { request.remote_ip }, with: -> { render_rate_limited }, only: :try_transcribe
  rate_limit to: 30, within: 1.hour,   by: -> { request.remote_ip }, with: -> { render_rate_limited }, only: :try_transcribe

  def home; end
  def pricing; end
  def privacidade; end
  def termos; end

  def try_transcribe
    audio = params[:audio]

    return render_demo_error("Áudio não enviado.",        status: :bad_request)          if audio.blank?
    return render_demo_error("Áudio muito grande.",       status: :payload_too_large)    if audio.size > MAX_UPLOAD_BYTES

    content_type = audio.content_type.to_s.split(";").first.presence || "audio/webm"
    unless content_type.start_with?("audio/")
      return render_demo_error("Formato inválido.", status: :unsupported_media_type)
    end

    transcript, duration = transcribe_demo_audio(audio, content_type)

    if duration && duration > MAX_DURATION
      return render_demo_error("Áudio muito longo. Limite de #{MAX_DURATION.to_i} segundos.", status: :unprocessable_entity)
    end

    if transcript.blank?
      return render_demo_error("Não foi possível entender o áudio. Tente falar um pouco mais alto.", status: :unprocessable_entity)
    end

    summary, full_formatted = nil, nil
    if transcript.length >= AI_MIN_CHARS
      summary, full_formatted = ai_format_demo(transcript)
    end

    render json: {
      transcript:     transcript,
      summary:        summary,
      full_formatted: full_formatted.presence || transcript,
      duration:       duration&.round(1)
    }
  rescue => e
    Rails.logger.error "[pages#try_transcribe] #{e.class}: #{e.message}"
    render_demo_error("Ocorreu um erro ao processar o áudio. Tente novamente.", status: :internal_server_error)
  end

  private

  def transcribe_demo_audio(audio, content_type)
    ext = File.extname(audio.original_filename.to_s).presence || ".webm"
    result = nil
    Tempfile.create(["wt_demo", ext], binmode: true) do |file|
      file.write(audio.read)
      file.flush
      dg   = Deepgram.new(file.path)
      text = dg.speech_to_text(content_type: content_type)
      result = [text, dg.duration]
    end
    result
  end

  def ai_format_demo(transcript)
    response = Llm::Client.new(model: "gpt-5.4-mini")
                          # Joga a verbosity e o thinking lá embaixo
                          .with_params(reasoning: {effort: 'low'}, text: {verbosity: 'low'})
                          .with_instructions(AI_PROMPT_DEMO)
                          .add_message(role: "user", content: transcript)
                          .complete

    result = JSON.parse(response.content, symbolize_names: true)
    [result[:summary], result[:full_formatted]]
  rescue => e
    Rails.logger.warn "[pages#try_transcribe] AI format failed: #{e.message}"
    [nil, nil]
  end

  def render_demo_error(message, status:)
    render json: { error: message }, status: status
  end

  def render_rate_limited
    render json: { error: "Muitas tentativas. Aguarde um momento e tente novamente." }, status: :too_many_requests
  end

  def page_layout
    return "legal" if action_name.in?(["privacidade", "termos"])

    "landing"
  end
end
