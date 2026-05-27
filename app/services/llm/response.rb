module Llm
  Response = Struct.new(:content, :input_tokens, :output_tokens, :response_id, keyword_init: true)
end
