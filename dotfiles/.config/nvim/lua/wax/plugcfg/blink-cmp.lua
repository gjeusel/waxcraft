local blink = require("blink.cmp")

---@module 'blink.cmp'
---@type blink.cmp.Config
local opts = {
  keymap = {
    preset = "default",
    --
    ["<C-e>"] = { "hide" },
    ["<C-c>"] = {
      function(cmp)
        if cmp.is_visible() then
          cmp.hide()
        end
        vim.cmd.stopinsert()
      end,
    },
    --
    ["<Tab>"] = { "select_next", "fallback" },
    --
    ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
    ["<C-s>"] = { "show_signature", "hide_signature", "fallback" },
    --
    ["<C-u>"] = { "scroll_documentation_up", "fallback" },
    ["<C-d>"] = { "scroll_documentation_down", "fallback" },
    --
    ["<C-j>"] = { "snippet_forward", "fallback" },
    ["<C-k>"] = { "snippet_backward", "fallback" },
  },
  completion = {
    trigger = {
      show_on_keyword = true,
      show_on_trigger_character = true,
    },
    menu = {
      draw = {
        columns = { { "label", gap = 1, "source_name" }, { "kind", gap = 1, "kind_icon" } },
      },
      auto_show = function(ctx)
        return ctx.mode ~= "cmdline"
      end,
    },
    list = {
      max_items = 6,
      selection = { preselect = false, auto_insert = true },
    },
    accept = { auto_brackets = { enabled = false } },
    -- ghost_text = { enabled = true },
    documentation = {
      window = {
        scrollbar = false,
        max_width = 80,
        max_height = math.floor(vim.o.lines * 0.3),
        border = "rounded",
      },
      -- auto_show = true,
      -- auto_show_delay_ms = 500,
    },
  },
  signature = { enabled = true, window = { border = "rounded" } },
  snippets = { preset = "luasnip" },
  sources = {
    default = {
      "lsp",
      "path",
      "snippets",
      "buffer",
      -- "ripgrep",
    },
    providers = {
      lsp = {},
      ripgrep = {
        module = "blink-ripgrep",
        name = "Ripgrep",
        min_keyword_length = 3,
        max_items = 2,
        score_offset = -0.1,
        should_show_items = function(ctx)
          return ctx.trigger.initial_kind ~= "trigger_character"
        end,
      },
      buffer = {
        opts = {
          get_bufnrs = function()
            return vim.tbl_filter(function(bufnr)
              return vim.bo[bufnr].buftype == ""
            end, vim.api.nvim_list_bufs())
          end,
        },
        should_show_items = function(ctx)
          return ctx.trigger.initial_kind ~= "trigger_character"
        end,
      },
      snippets = {
        score_offset = 0.1,
        min_keyword_length = 2,
        max_items = 2,
        should_show_items = function(ctx)
          return ctx.trigger.initial_kind ~= "trigger_character"
        end,
      },
    },
  },
  fuzzy = {
    sorts = { "score", "sort_text" },
    prebuilt_binaries = { ignore_version_mismatch = true },
  },
}

blink.setup(opts)
