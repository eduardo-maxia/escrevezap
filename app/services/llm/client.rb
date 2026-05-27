# Orchestration layer over the OpenAI Responses API.
# Always uses responses.create – never chat completions.
#
# Usage:
#   client = Llm::Client.new(model: 'gpt-4o')
#     .with_instructions("You are …")
#     .with_tools(*my_tools)
#     .with_temperature(0.3)
#     .with_params(reasoning_effort: 'medium')
#
#   client.add_message(role: 'user', content: 'Hello')
#   response = client.complete
#   # => Llm::Response  or  Llm::HaltSignal
module Llm
  class Client
    include Loggable

  MAX_ITERATIONS = 10

  # Lightweight struct passed to on_tool_call callbacks.
  # Mirrors the shape of RubyLLM::ToolCall for easy migration.
  ToolCallStub = Struct.new(:call_id, :name, :arguments, keyword_init: true)

  def initialize(model: "gpt-5.4-mini")
    @openai       = OpenAI::Client.new(
      api_key: Rails.application.credentials.dig(:openai, :api_key)
    )
    @model        = model
    @instructions = nil
    @tools        = []
    @input        = []
    @extra_params = {}
    @tool_call_callbacks   = []
    @tool_result_callbacks = []
  end

  # ── Configuration (chainable) ──────────────────────────────────────────

  def with_instructions(text, replace: false)
    @instructions = text
    self
  end

  def with_tools(*tools)
    @tools = tools.flatten
    self
  end

  def with_temperature(value)
    # @extra_params[:temperature] = value
    self
  end

  # Pass any additional Responses API params (e.g. reasoning_effort:, truncation:).
  def with_params(**params)
    @extra_params.merge!(params)
    self
  end

  # ── History building ───────────────────────────────────────────────────

  # Adds a plain user/assistant message.
  def add_message(role:, content:)
    @input << { role: role.to_s, content: content.to_s }
    self
  end

  # Adds a function_call item (the model's tool invocation) to input history.
  # Use when replaying past tool calls from the database.
  def add_tool_call(call_id:, name:, arguments:)
    args_str = arguments.is_a?(String) ? arguments : arguments.to_json
    @input << { type: 'function_call', call_id: call_id, name: name, arguments: args_str }
    self
  end

  # Adds a function_call_output item (our result) to input history.
  # Use when replaying past tool results from the database.
  def add_tool_result(call_id:, output:)
    out_str = output.is_a?(String) ? output : output.to_json
    @input << { type: 'function_call_output', call_id: call_id, output: out_str }
    self
  end

  # ── Callbacks ──────────────────────────────────────────────────────────

  # Block receives a ToolCallStub with .call_id, .name, .arguments (JSON string).
  # Called right before the tool executes.
  def on_tool_call(&block)
    @tool_call_callbacks << block
    self
  end

  # Block receives (call_id, result_hash).
  # Called right after the tool executes (even on error).
  def on_tool_result(&block)
    @tool_result_callbacks << block
    self
  end

  # ── Execution ──────────────────────────────────────────────────────────

      # Runs the agentic loop and returns either a Llm::Response or a
  # Llm::HaltSignal (when a tool calls halt()).
  def complete
    run_agentic_loop(@input.dup)
  end

  private

  def run_agentic_loop(input)
    iterations = 0

    loop do
      raise "Max tool-call iterations (#{MAX_ITERATIONS}) exceeded" if iterations >= MAX_ITERATIONS

      response = call_responses_api(input)
      log_info "Responses API call #{iterations + 1}: #{response.usage&.output_tokens} output tokens"

      function_calls = response.output.select { |item| item.type == :function_call }
      return build_result(response) if function_calls.empty?

      halt_signal = nil

      function_calls.each do |fc|
        stub = ToolCallStub.new(call_id: fc.call_id, name: fc.name, arguments: JSON.parse(fc.arguments))
        @tool_call_callbacks.each { |cb| cb.call(stub) }

        # Persist model's function_call into input so the conversation stays coherent.
        input << { type: 'function_call', call_id: fc.call_id, name: fc.name, arguments: fc.arguments }

        tool   = @tools.find { |t| t.tool_name == fc.name }
        args   = parse_arguments(fc.arguments)
        result = execute_tool(tool, args, fc.name)

        if result.is_a?(Llm::BaseTool::Halt)
          halt_signal = Llm::HaltSignal.new(result.content)
          result = { halted: true, **result.content }
        end

        @tool_result_callbacks.each { |cb| cb.call(fc.call_id, result) }
        input << { type: 'function_call_output', call_id: fc.call_id, output: result.to_json }
      end

      return halt_signal if halt_signal

      iterations += 1
    end
  end

  def call_responses_api(input)
    # Se o input veio vazio, significa que estamos chamando a API com todas as intruções no system prompt. Nesse caso, passamos um input mínimo para evitar erros de input vazio.
    input = [{ role: 'user', content: 'Responda seguindo as instruções do prompt' }] if input.empty?
    params = { model: @model, input: input }
    params[:instructions] = @instructions if @instructions.present?
    params[:tools]        = @tools.map(&:tool_definition) if @tools.any?

    extra = @extra_params.dup
    params.merge!(extra)

    @openai.responses.create(**params)
  end

  def execute_tool(tool, args, name)
    if tool
      tool.execute(**args)
    else
      log_warning "Tool '#{name}' not found among registered tools"
      { error: "Tool '#{name}' not found" }
    end
  rescue => e
    log_error "Tool '#{name}' raised: #{e.message}"
    { error: e.message }
  end

  def parse_arguments(json_str)
    JSON.parse(json_str, symbolize_names: true)
  rescue JSON::ParserError
    {}
  end

  def build_result(response)
    message_item = response.output.find { |item| item.type == :message }
    text = message_item
              &.content
              &.find { |c| c.type == :output_text }
              &.text

    Llm::Response.new(
      content:       text,
      input_tokens:  response.usage&.input_tokens,
      output_tokens: response.usage&.output_tokens,
      response_id:   response.id
    )
  end
  end
end
