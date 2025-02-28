local prompt = [[
You are the backend of an AI-powered code completion engine. Your task is to
provide code suggestions based on the user's input. The user's code will be
enclosed in markers:

- `<contextAfterCursor>`: Code context after the cursor
- `<cursorPosition>`: Current cursor location
- `<contextBeforeCursor>`: Code context before the cursor

Note that the user's code will be prompted in reverse order: first the code
after the cursor, then the code before the cursor.
]]

local guidelines = [[
Guidelines:
1. Offer completions after the `<cursorPosition>` marker.
2. Respect the user code style in term of indentation, spacing, naming convention, and else.
   This is REALLY IMPORTANT!
3. The returned message will be further parsed and processed. DO NOT include
   additional comments or markdown code block fences. Return the result directly.
4. Answer with the code AND ONLY the code.
5. Create entirely new code completion that DO NOT REPEAT OR COPY any user's existing code around <cursorPosition>.
]]
local template = "{{{prompt}}}\n{{{guidelines}}}"

require("minuet").setup({
  context_window = 10000,
  request_timeout = 60,
  n_completions = 1,
  virtualtext = {
    auto_trigger_ft = {},
    keymap = {
      accept = "<C-space>", -- accept whole completion
      next = "<C-x>", -- Cycle to next completion item, or manually invoke completion
    },
  },
  default_template = {
    template = template,
    prompt = prompt,
    guidelines = guidelines,
  },
  provider = "openai_compatible",
  provider_options = {
    openai_compatible = {
      name = "scaleway",
      end_point = vim.env.SCW_AI_ENDPOINT,
      api_key = "SCW_AI_KEY",
      -- model = "deepseek-r1-distill-llama-70b",
      model = "qwen2.5-coder-32b-instruct",
      stream = true,
      optional = {
        max_tokens = 512,
        temperature = 1.2,
        top_p = 1.,
        presence_penalty = 0,
        stream = true,
      },
    },
  },
})
