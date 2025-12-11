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

local source_priority = {
  "snippets",
  "lsp",
  "path",
  "buffer",
  "ripgrep",
}

-- Prioritize ty LSP auto-imports from Python stdlib (set to nil to disable)
-- stylua: ignore
local python_stdlib_priority = {
  typing = 1, typing_extensions = 2, collections = 3, abc = 4, functools = 5,
  itertools = 6, dataclasses = 7, enum = 8, re = 9, os = 10, sys = 11,
  pathlib = 12, json = 13, datetime = 14, contextlib = 15, io = 16, copy = 17, math = 18,
  pydantic = 19,
}

local function get_ty_item_priority(item)
  if item.client_name ~= "ty" then
    return nil
  end
  local ld = item.labelDetails
  if not ld then
    return nil
  end
  local detail = ld.detail
  if not detail then
    return nil
  end
  local start = detail:find("(import ", 1, true)
  if not start then
    return nil
  end
  local mod_start = start + 8
  local dot = detail:find(".", mod_start, true)
  local paren = detail:find(")", mod_start, true)
  local mod_end = (dot and paren and (dot < paren and dot or paren)) or dot or paren
  if not mod_end or mod_end <= mod_start then
    return nil
  end
  return python_stdlib_priority[detail:sub(mod_start, mod_end - 1)]
end

local function dedupe_lsp_items(lsp_items)
  local by_label, prio_cache = {}, {}
  local n = #lsp_items
  local get_prio = get_ty_item_priority
  -- local get_prio = nil

  for i = 1, n do
    local item = lsp_items[i]
    local label = item.label
    local existing = by_label[label]
    if not existing then
      by_label[label] = item
      if get_prio then
        prio_cache[label] = get_prio(item)
      end
    elseif get_prio then
      local item_prio = get_prio(item)
      if item_prio and (not prio_cache[label] or item_prio < prio_cache[label]) then
        by_label[label] = item
        prio_cache[label] = item_prio
      end
    end
  end

  local filtered, j = {}, 0
  for i = 1, n do
    local label = lsp_items[i].label
    local best = by_label[label]
    if best then
      j = j + 1
      filtered[j] = best
      by_label[label] = nil
    end
  end
  return filtered
end

local function dedupe_sources(items_by_source)
  local seen = {}
  local lsp = items_by_source["lsp"]
  if lsp then
    for i = 1, #lsp do
      seen[lsp[i].label] = true
    end
  end

  local sp = source_priority
  for i = 1, #sp do
    local id = sp[i]
    if id ~= "lsp" then
      local items = items_by_source[id]
      if items then
        local filtered, j = {}, 0
        for k = 1, #items do
          local item = items[k]
          local label = item.label
          if not seen[label] then
            seen[label] = true
            j = j + 1
            filtered[j] = item
          end
        end
        items_by_source[id] = filtered
      end
    end
  end
end

-- https://github.com/Saghen/blink.cmp/issues/1222
local original = require("blink.cmp.completion.list").show
---@diagnostic disable-next-line: duplicate-set-field
require("blink.cmp.completion.list").show = function(ctx, items_by_source)
  local lsp_items = items_by_source["lsp"]
  if lsp_items then
    items_by_source["lsp"] = dedupe_lsp_items(lsp_items)
  end
  dedupe_sources(items_by_source)
  return original(ctx, items_by_source)
end

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
      show_on_keyword = true,
      show_on_trigger_character = true,
      -- show_on_accept_on_trigger_character = true,
      -- show_on_insert_on_trigger_character = true,
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
    per_filetype = {
      ["dap-repl"] = { "dap" },
    },
    providers = {
      lsp = {
        score_offset = 10,
      },
      ripgrep = {
        module = "blink-ripgrep",
        name = "rg",
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
        score_offset = 20,
        min_keyword_length = 2,
        max_items = 2,
        should_show_items = function(ctx)
          return ctx.trigger.initial_kind ~= "trigger_character"
        end,
      },
      dap = {
        name = "dap",
        module = "blink.compat.source",
      },
    },
  },
  fuzzy = {
    ---@diagnostic disable-next-line: unused-local
    max_typos = function(keyword)
      return 0 -- 0 means same behaviour as fzf
      -- return math.floor(#keyword / 4)
    end,
    frecency = {
      enabled = false,
    },
    sorts = { "score", "sort_text" },
  },
}

blink.setup(opts)
