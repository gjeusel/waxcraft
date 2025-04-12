local blink = require("blink.cmp")

local keymap = {
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
  ["<CR>"] = { "select_and_accept", "fallback" },
  --
  ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
  ["<C-s>"] = { "show_signature", "hide_signature", "fallback" },
  --
  ["<C-u>"] = { "scroll_documentation_up", "fallback" },
  ["<C-d>"] = { "scroll_documentation_down", "fallback" },
  --
  ["<C-j>"] = { "snippet_forward", "fallback" },
  ["<C-k>"] = { "snippet_backward", "fallback" },
}

---@module 'blink.cmp'
---@type blink.cmp.Config
local opts = {
  enabled = function()
    local disabled_filetypes = { "DressingInput" }
    return not vim.tbl_contains(disabled_filetypes, vim.bo.filetype)
  end,
  keymap = keymap,
  completion = {
    trigger = {
      show_on_keyword = true,
      show_on_trigger_character = true,
      -- show_on_accept_on_trigger_character = true,
      -- show_on_insert_on_trigger_character = true,
    },
    menu = {
      draw = {
        padding = 1,
        gap = 5,
        columns = {
          { "label", gap = 1 },
          { "kind_icon", "kind", gap = 1 },
          -- { "source_name" },
        },
        components = {
          label = {
            width = { fill = true, max = 60 },
          },
          source_name = {
            width = { max = 30 },
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
  cmdline = { enabled = false },
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
    providers = {
      lsp = {},
      ripgrep = {
        module = "blink-ripgrep",
        name = "rg",
        min_keyword_length = 3,
        max_items = 2,
        score_offset = -0.1,
        -- should_show_items = function(ctx)
        --   return ctx.trigger.initial_kind ~= "trigger_character"
        -- end,
        transform_items = function(_, items)
          for _, item in ipairs(items) do
            item.kind_icon = "®"
            item.kind_name = "rg"
          end
          return items
        end,

        opts = {
          prefix_min_len = 3,
          context_size = 5,
          max_filesize = "200K",
          search_casing = "--smart-case",
          ignore_paths = { vim.env.HOME },
          future_features = {
            issue185_workaround = true, -- https://github.com/mikavilpas/blink-ripgrep.nvim/issues/185
            -- ☝🏻
          },
        },
      },
      buffer = {
        opts = {
          get_bufnrs = function()
            return vim.tbl_filter(function(bufnr)
              return vim.bo[bufnr].buftype == ""
            end, vim.api.nvim_list_bufs())
          end,
        },
        -- should_show_items = function(ctx)
        --   return ctx.trigger.initial_kind ~= "trigger_character"
        -- end,
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

    -- Waiting for better:
    -- https://github.com/Saghen/blink.cmp/issues/1222
    transform_items = function(_, items)
      local seen = {}
      local result = {}

      for _, item in ipairs(items) do
        local value = item.label
        if not seen[value] then
          seen[value] = true
          table.insert(result, item)
        end
      end
      log.warn(result)
      return result
    end,
  },
  fuzzy = {
    max_typos = function(keyword)
      return 0 -- 0 means same behaviour as fzf
      -- return math.floor(#keyword / 4)
    end,
    sorts = { "score", "sort_text" },
    prebuilt_binaries = { force_version = "v1.1.1", ignore_version_mismatch = true },
  },
}

blink.setup(opts)
