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
    ["<C-y>"] = cmp.mapping.confirm({ select = true }),
    [")"] = cmp.mapping(close_parenth_cursor_right, { "i", "s" }),
    ["<CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    }),
    ["<C-d>"] = cmp.mapping.scroll_docs(4),
    ["<C-u>"] = cmp.mapping.scroll_docs(-4),
    ["<C-e>"] = cmp.mapping.close(),
    ["<C-c>"] = cmp.mapping(control_c_close, { "i" }),
    -- ["<C-Space>"] = cmp.mapping(expand_snippet, { "i", "s" }),
  },
  sources = {
    { name = "luasnip" },
    { name = "nvim_lua" },
    { name = "nvim_lsp", priority = 100 },
    { -- buffer
      name = "buffer",
      keyword_length = 3,
      max_item_count = 5,
      options = {
        get_bufnrs = function()
          local bufs = {}
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            bufs[vim.api.nvim_win_get_buf(win)] = true
          end
          return vim.tbl_keys(bufs)
        end,
      },
    },
    { name = "path" },
    -- { name = "treesitter" },
  },
  sorting = {
    priority_weight = 1.1,
    comparators = {
      compare.offset,
      compare.exact,
      compare.score,
      compare.kind,
      compare.sort_text,
      compare.length,
      compare.order,
    },
  },
  formatting = {
    format = function(entry, vim_item)
      -- fancy icons and a name of kind
      vim_item.kind = lspkind.presets.default[vim_item.kind] .. " " .. vim_item.kind

      -- set a name for each source
      vim_item.menu = ({
        nvim_lua = "[Lua]",
        buffer = "[Buffer]",
        nvim_lsp = "[LSP]",
        path = "[Path]",
      })[entry.source.name]

      -- disable duplicate keys
      vim_item.dup = 0

      -- set max width with abbr
      if string.len(vim_item.abbr) > 25 then
        vim_item.abbr = string.sub(vim_item.abbr, 1, 20) .. " ... "
      end
      return vim_item
    end,
  },
  -- documentation = false, -- disable doc window
  documentation = {
    maxwidth = 80,
    max_height = math.floor(vim.o.lines * 0.3),
    border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  },
  experimental = {
    -- native_menu = false,
  },
})
