local cmp = require("cmp")
local compare = require("cmp.config.compare")
local lspkind = require("lspkind")

local utils_autopairs = require("nvim-autopairs.utils")

local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local cycle_forward = function(fallback)
  if cmp.visible() then
    cmp.select_next_item({ behavior = cmp.SelectBehavior.Inserts })
  else
    fallback()
  end
end

local cycle_backward = function(fallback)
  if cmp.visible() then
    cmp.select_prev_item({ behavior = cmp.SelectBehavior.Inserts })
  else
    fallback()
  end
end

local control_c_close = function(fallback)
  if cmp.visible() then
    vim.fn.feedkeys(t("<Esc>"))
  else
    fallback()
  end
end

-- Using ")" completes with select and add () for Method and Function
local close_parenth_cursor_right = function(fallback)
  local kinds = { cmp.lsp.CompletionItemKind.Method, cmp.lsp.CompletionItemKind.Function }

  if cmp.visible() then
    local entry = cmp.get_active_entry()
    if entry then
      local item = entry:get_completion_item()
      if utils_autopairs.is_in_table(kinds, item.kind) then
        cmp.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = true }, function()
          utils_autopairs.feed("(")
          utils_autopairs.feed(")")
        end)
      else
        cmp.close()
        fallback()
      end
    else
      cmp.close()
      fallback()
    end
    return
  end

  fallback()
end

cmp.setup({
  completion = {
    keyword_length = 1,
  },
  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end,
  },
  mapping = {
    ["<Tab>"] = cmp.mapping(cycle_forward, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(cycle_backward, { "i", "s" }),
    ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Inserts }),
    ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Inserts }),
    -- ["<C-y>"] = cmp.mapping.confirm({ select = true }),
    -- ["C-y"] = cmp.mapping(function(fallback)
    --   fallback()
    -- end),
    -- [")"] = cmp.mapping(close_parenth_cursor_right, { "i", "s" }),
    ["<CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = false,
    }),
    ["<C-d>"] = cmp.mapping.scroll_docs(4),
    ["<C-u>"] = cmp.mapping.scroll_docs(-4),
    ["<C-e>"] = cmp.mapping.close(),
    ["<C-c>"] = cmp.mapping(control_c_close, { "i" }),
    -- ["<C-Space>"] = cmp.mapping(expand_snippet, { "i", "s" }),
  },
  sources = {
    { name = "nvim_lua" },
    { name = "luasnip", max_item_count = 2 },
    { name = "nvim_lsp", max_item_count = 5 },
    { -- buffer
      name = "buffer",
      keyword_length = 3,
      max_item_count = 5,
      options = {
        get_bufnrs = function()
          return vim.api.nvim_list_bufs()
          -- local bufs = {}
          -- for _, win in ipairs(vim.api.nvim_list_wins()) do
          --   bufs[vim.api.nvim_win_get_buf(win)] = true
          -- end
          -- return vim.tbl_keys(bufs)
        end,
      },
    },
    -- { name = "copilot", max_item_count = 3, keyword_length = 5 },
    { name = "path" },
    -- { name = "treesitter" },
  },
  sorting = {
    priority_weight = 2,
    comparators = {
      -- require("copilot_cmp.comparators").prioritize,
      -- require("copilot_cmp.comparators").score,

      -- Below is the default comparitor list and order for nvim-cmp
      cmp.config.compare.offset,
      -- cmp.config.compare.scopes, --this is commented in nvim-cmp too
      cmp.config.compare.exact,
      cmp.config.compare.score,
      cmp.config.compare.recently_used,
      cmp.config.compare.locality,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  },
  formatting = {
    format = function(entry, vim_item)
      -- Special case of copilot
      if entry.source.name == "copilot" then
        vim_item.kind = "    AI"
        return vim_item
      end

      -- fancy icons and a name of kind
      vim_item.kind = lspkind.presets.default[vim_item.kind] .. " " .. vim_item.kind

      -- set a name for each source
      vim_item.menu = ({
        nvim_lua = "[Lua]",
        buffer = "[Buffer]",
        nvim_lsp = "[LSP]",
        path = "[Path]",
        luasnip = "[Snip]",
        copilot = "[AI]",
      })[entry.source.name]

      -- disable duplicate keys: https://github.com/hrsh7th/nvim-cmp/issues/32
      vim_item.dup = ({
        buffer = 1,
        path = 1,
        nvim_lsp = 0,
      })[entry.source.name] or 0

      -- set max width with abbr
      if string.len(vim_item.abbr) > 25 then
        vim_item.abbr = string.sub(vim_item.abbr, 1, 20) .. " ... "
      end
      return vim_item
    end,
  },
  window = {
    -- documentation = false, -- disable doc window
    documentation = {
      maxwidth = 80,
      max_height = math.floor(vim.o.lines * 0.3),
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    },
  },
})
