class GptTranscribe
  include Loggable

  MODEL = "gpt-4o-transcribe"

  # Prompt gives the model context about Brazilian Portuguese WhatsApp audio and
  # hints at common terms that speech recognition tends to mishear.
  PROMPT = "Áudio de WhatsApp em português brasileiro. " \
           "Preserve palavras como: Pix, WhatsApp, CNPJ, CPF, boleto, reais."

  # Exposed after speech_to_text completes.
  # duration     – audio length in seconds (Float), populated when the API
  #                returns a duration-type usage (nil otherwise).
  # total_tokens – total tokens billed, populated when the API returns a
  #                token-type usage (nil otherwise).
  attr_reader :duration, :total_tokens

  def initialize(audio_file_path)
    @audio_file_path = audio_file_path
    @duration        = nil
    @total_tokens    = nil
  end

  def speech_to_text
    log_info "Convertendo áudio para texto com #{MODEL}"

    client = OpenAI::Client.new(
      api_key: Rails.application.credentials.dig(:openai, :api_key)
    )

    File.open(@audio_file_path, "rb") do |audio_file|
      response = client.audio.transcriptions.create(
        file:            audio_file,
        model:           MODEL,
        language:        "pt",
        response_format: "json",
        prompt:          PROMPT,
        include:         ["usage"]
      )

      extract_usage(response.usage)
      response.text
    end
  end

  private

  def extract_usage(usage)
    return unless usage

    case usage.type
    when :tokens
      @total_tokens = usage.total_tokens
    when :duration
      @duration = usage.seconds
    end
  end
end
