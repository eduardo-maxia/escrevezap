module Llm
  module BaseTool
    Halt = Struct.new(:content, keyword_init: true)
  end
end
