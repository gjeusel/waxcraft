require("copilot").setup({
  panel = {
    enabled = true,
    auto_refresh = false,
    keymap = {
      jump_prev = "[[",
      jump_next = "]]",
      accept = "<CR>",
      refresh = "gr",
      open = "<C-x>",
    },
    layout = {
      position = "bottom", -- | top | left | right
      ratio = 0.4,
    },
  },
  suggestion = {
    enabled = false,
    -- auto_trigger = true,
    -- debounce = 75,
    -- keymap = {
    --   accept = "<C-x>",
    --   -- accept_word = false,
    --   -- accept_line = false,
    --   -- next = "<M-]>",
    --   -- prev = "<M-[>",
    --   -- dismiss = "<C-]>",
    -- },
  },
  server_opts_overrides = {
    -- trace = "verbose",
    settings = {
      inlineSuggest = { enabled = false },
      editor = {
        showEditorCompletions = false,
        enableAutoCompletions = false,
      },
      advanced = {
        top_p = 0.70,
        listCount = 3, -- #completions for panel
        inlineSuggestCount = 0, -- #completions for getCompletions
        enableAutoCompletions = false,
      },
    },
  },
})
