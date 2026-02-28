local blink = require("blink.cmp")

local keymap = {
  preset = "none",
  --
  ["<C-e>"] = false,
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
  ["<C-n>"] = { "select_next", "fallback" },
  ["<C-p>"] = { "select_prev", "fallback" },

  ["<CR>"] = { "select_and_accept", "fallback" },
  ["<C-y>"] = { "select_and_accept", "fallback" },
  --
  ["<C-f>"] = { "show", "show_documentation", "hide_documentation" },
  ["<C-s>"] = { "show_signature", "hide_signature", "fallback" },
  --
  ["<C-u>"] = { "scroll_documentation_up", "fallback" },
  ["<C-d>"] = { "scroll_documentation_down", "fallback" },
  --
  ["<C-j>"] = { "snippet_forward", "fallback" },
  ["<C-k>"] = { "snippet_backward", "fallback" },
}

---@module 'blink.cmp'
---@diagnostic disable-next-line: undefined-doc-name
---@type blink.cmp.Config
local opts = {
  enabled = function()
    local disabled_filetypes = { "DressingInput" }
    return not vim.tbl_contains(disabled_filetypes, vim.bo.filetype)
  end,
  keymap = keymap,
  completion = {
    trigger = {
      prefetch_on_insert = true,
      show_on_keyword = true,
      show_on_trigger_character = true,
    },
    menu = {
      border = "none",
      max_height = 5,
      draw = {
        padding = 1,
        gap = 5,
        columns = {
          { "label", gap = 1 },
          { "kind_icon", "kind", "source_name", gap = 1 },
        },
        components = {
          label = {
            width = { fill = true, max = 40 },
          },
          source_name = {
            width = { max = 10 },
            text = function(ctx)
              return ctx.item.client_name
            end,
            highlight = "BlinkCmpSource",
          },
        },
      },
      -- auto_show = function(ctx)
      --   if ctx == nil then
      --     return false
      --   end
      --   return ctx.mode ~= "cmdline"
      -- end,
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
  cmdline = {
    enabled = true,
    keymap = { preset = "cmdline" },
    completion = {
      list = { selection = { preselect = false, auto_insert = true } },
      menu = {
        auto_show = function(ctx, _)
          return ctx.mode == "cmdwin"
        end,
      },
      ghost_text = { enabled = true },
    },
    sources = function()
      local type = vim.fn.getcmdtype()
      -- Search forward and backward
      if type == "/" or type == "?" then
        return { "buffer" }
      end
      -- Commands
      if type == ":" or type == "@" then
        return { "cmdline", "buffer" }
      end
      return {}
    end,
  },
  signature = { enabled = true, trigger = { enabled = false }, window = { border = "rounded" } },
  snippets = { preset = "luasnip" },
  sources = {
    default = {
      "lsp",
      "path",
      "snippets",
      "buffer",
      "ripgrep",
    },
    per_filetype = {
      ["dap-repl"] = { "dap" },
    },
    providers = {
      lsp = {
        score_offset = 10,
        async = true,
      },
      ripgrep = {
        module = "blink-ripgrep",
        name = "rg",
        async = true,
        min_keyword_length = 3,
        opts = {
          prefix_min_len = 4,
          debounce = 200,
          project_root_marker = { ".git", "pyproject.toml", "package.json" },
          backend = {
            ripgrep = {
              context_size = 5,
              max_filesize = "100K",
              search_casing = "--smart-case",
              ignore_paths = { vim.env.HOME },
            },
          },
          transform_items = function(_, items)
            for _, item in ipairs(items) do
              item.kind_icon = "®"
              item.kind_name = "rg"
            end
            return items
          end,
        },
      },
      buffer = {
        min_keyword_length = 2,
        async = true,
      },
      snippets = {
        score_offset = 20,
        min_keyword_length = 2,
        max_items = 2,
        async = true,
        should_show_items = function(ctx)
          return ctx.trigger.initial_kind ~= "trigger_character"
        end,
      },
      dap = {
        name = "dap",
        module = "blink.compat.source",
        async = true,
      },
    },
  },
  fuzzy = {
    implementation = "prefer_rust_with_warning",
    ---@diagnostic disable-next-line: unused-local
    max_typos = function(keyword)
      return 0 -- 0 means same behaviour as fzf
    end,
    frecency = {
      enabled = false,
    },
    sorts = { "score", "sort_text" },
  },
}

blink.setup(opts)
