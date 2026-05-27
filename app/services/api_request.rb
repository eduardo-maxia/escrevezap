require "net/http"
require "uri"
require "json"
require "timeout"
require "securerandom"

class ApiRequest
  include Loggable
  class ApiError < StandardError; end
  class ApiClientError < ApiError; end       # Erros 4xx
  class ApiServerError < ApiError; end       # Erros 5xx
  class ApiConnectionError < ApiError; end    # Erros de conexão/timeout
  class ApiParsingError < ApiError; end      # Erros ao parsear JSON

  attr_reader :base_url, :default_headers

  def initialize(base_url, default_headers = {}, proxy: false)
    @base_url = base_url
    @default_headers = { "Content-Type" => "application/json", "Accept" => "application/json" }.merge(default_headers)
    @proxy = proxy
  end

  def get(path, params = {}, headers = {}, body = {})
    uri = build_uri(path, params)
    request_path = uri.path + (uri.query ? "?#{uri.query}" : "")
    request = Net::HTTP::Get.new(request_path)
    request.body = body.to_json unless body.empty?

    perform_request(uri, request, headers)
  end

  def post(path, body = {}, headers = {})
    uri = build_uri(path)
    request_path = uri.path + (uri.query ? "?#{uri.query}" : "")
    request = Net::HTTP::Post.new(request_path)
    request.body = body.to_json unless body.empty?

    perform_request(uri, request, headers)
  end

  def patch(path, body = {}, headers = {})
    uri = build_uri(path)
    request_path = uri.path + (uri.query ? "?#{uri.query}" : "")
    request = Net::HTTP::Patch.new(request_path)
    request.body = body.to_json unless body.empty?

    perform_request(uri, request, headers)
  end

  def put(path, body = {}, headers = {})
    uri = build_uri(path)
    request_path = uri.path + (uri.query ? "?#{uri.query}" : "")
    request = Net::HTTP::Put.new(request_path)
    request.body = body.to_json unless body.empty?

    perform_request(uri, request, headers)
  end

  def delete(path, params = {}, headers = {})
    uri = build_uri(path, params)
    request_path = uri.path + (uri.query ? "?#{uri.query}" : "")
    request = Net::HTTP::Delete.new(request_path)

    perform_request(uri, request, headers)
  end

  def post_multipart(path, params = {}, file = nil, headers = {})
    uri = build_uri(path)
    request_path = uri.path + (uri.query ? "?#{uri.query}" : "")
    request = Net::HTTP::Post.new(request_path)

    # Criar o boundary para o multipart
    boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"

    # Criar o corpo da requisição multipart
    post_body = []

    # Adicionar os parâmetros
    params.each do |key, value|
      post_body << "--#{boundary}"
      post_body << "Content-Disposition: form-data; name=\"#{key}\""
      post_body << ""
      post_body << value.to_s
    end

    # Adicionar o arquivo se existir
    if file
      post_body << "--#{boundary}"
      post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(file.path)}\""
      post_body << "Content-Type: audio/wav"
      post_body << ""
      post_body << file.read
    end

    # Fechar o boundary
    post_body << "--#{boundary}--"

    # Definir o Content-Type com o boundary
    headers["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

    # Definir o corpo da requisição
    request.body = post_body.join("\r\n")

    perform_request(uri, request, headers)
  end

  private

  def request_path(uri)
    uri.path + (uri.query ? "?#{uri.query}" : "")
  end

  def build_uri(path, params = {})
    full_url = "#{base_url}#{path}"

    uri = URI.parse(full_url)
    uri.query = URI.encode_www_form(params) unless params.empty?

    uri
  end

  def set_headers(request, specific_headers)
    merged_headers = default_headers.merge(specific_headers)
    merged_headers.each do |key, value|
      request[key] = value
    end
  end

  def perform_request(uri, request, specific_headers = {})
    set_headers(request, specific_headers)

    response = begin
      # Configuração com proxy opcional
      if @proxy
        http = Net::HTTP.new(
          uri.hostname,
          uri.port,
          # @proxy_config[:address],
          'dc.decodo.com',
          # @proxy_config[:port],
          10001,
          'spyw85q1w5',
          '5lqAk2X0x~ZhlW6vir'
          # @proxy_config[:user],      # Opcional
          # @proxy_config[:password]   # Opcional
        )
      else
        http = Net::HTTP.new(uri.hostname, uri.port)
      end

      http.use_ssl = (uri.scheme == 'https')

      # Configurar timeouts
      # http.open_timeout = 10 # Tempo para abrir a conexão
      http.read_timeout = 200 # Tempo para ler a resposta

      log_info "API Request: #{request.method} #{uri}"

      http.request(request)
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
           Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
           Errno::ECONNREFUSED, SocketError => e
      error_message = "Erro de conexão: #{request.method} #{uri}: #{e.class} - #{e.message}"
      log_error error_message
      raise ApiConnectionError, error_message
    end

    log_info "API Response: Status: #{response.code}"

    handle_response(response, uri, request.method)
  end

  def handle_response(response, uri, method)
    if response["Content-Type"] == "audio/mpeg" # Caso especial para retorno de audio da ElevenLabs
      return response.body
    end

    case response
    when Net::HTTPSuccess # 2xx
      if response["Content-Type"] != "application/json"
        return response.body
      end

      parse_json(response.body)
    when Net::HTTPFound # 3xx
      response["Location"]
    when Net::HTTPClientError # 4xx
      error_message = "Client error for #{method} #{uri}: #{response.code} #{response.message}. Body: #{response.body}"
      log_error error_message
      raise ApiClientError, error_message
    when Net::HTTPServerError # 5xx
      error_message = "Server error for #{method} #{uri}: #{response.code} #{response.message}. Body: #{response.body}"
      log_error error_message
      raise ApiServerError, error_message
    else
      error_message = "Unexpected HTTP response for #{method} #{uri}: #{response.code} #{response.message}"
      log_error error_message
      raise ApiError, error_message # Erro genérico para outros códigos
    end
  end

  def parse_json(body)
    return nil if body.nil? || body.strip.empty?

    begin
      JSON.parse(body)
    rescue JSON::ParserError => e
      error_message = "Erro ao parsear JSON: #{e.message}. Body: #{body.slice(0, 100)}..."
      log_error error_message
      raise ApiParsingError, error_message
    end
  end
end
