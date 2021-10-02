local cmp = require("cmp")
local compare = require("cmp.config.compare")
local lspkind = require("lspkind")

local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local check_back_space = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col == 0 or vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
    :sub(col, col)
    :match("%s") ~= nil
end

local cycle_forward = function(fallback)
  -- if vim.fn.complete_info()["selected"] == -1 then
  --   -- if vim.fn["UltiSnips#CanExpandSnippet"]() == 1 then
  --   --   vim.fn.feedkeys(t("<C-R>=UltiSnips#ExpandSnippet()<CR>"))
  --   -- end
  --   -- if want to jump inside snippet with tab:
  --   -- elseif vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
  --   --   vim.fn.feedkeys(t("<ESC>:call UltiSnips#JumpForwards()<CR>"))

  if vim.fn.pumvisible() == 1 then
    vim.fn.feedkeys(t("<C-n>"), "n")
  elseif check_back_space() then
    vim.fn.feedkeys(t("<tab>"), "n")
  else
    fallback()
  end
end

local cycle_backward = function(fallback)
  -- if want to jump inside snippet with tab:
  -- if vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
  --   return vim.fn.feedkeys(t("<C-R>=UltiSnips#JumpBackwards()<CR>"))
  if vim.fn.pumvisible() == 1 then
    vim.fn.feedkeys(t("<C-p>"), "n")
  else
    fallback()
  end
end

local expand_snippet = function(fallback)
  if vim.fn.pumvisible() == 1 then
    -- if vim.fn["UltiSnips#CanExpandSnippet"]() == 1 then
    --   return vim.fn.feedkeys(t("<C-R>=UltiSnips#ExpandSnippet()<CR>"))
    -- end
    vim.fn.feedkeys(t("<C-n>"), "n")
  elseif check_back_space() then
    vim.fn.feedkeys(t("<cr>"), "n")
  else
    fallback()
  end
end

local control_c_close = function(fallback)
  if vim.fn.pumvisible() == 1 then
    vim.fn.feedkeys(t("<Esc>"))
  else
    fallback()
  end
end

cmp.setup({
  completion = {
    keyword_length = 1,
  },
  -- snippet = {
  --   expand = function(args)
  --     vim.fn["UltiSnips#Anon"](args.body)
  --   end,
  -- },
  mapping = {
    ["<C-y>"] = cmp.mapping.confirm({ select = true }),
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-e>"] = cmp.mapping.close(),
    ["<C-c>"] = cmp.mapping(control_c_close, { "i" }),
    ["<CR>"] = cmp.mapping.confirm({
      -- behavior = cmp.ConfirmBehavior.Replace,
      -- select = true,
    }),
    ["<C-Space>"] = cmp.mapping(expand_snippet, { "i", "s" }),
    ["<Tab>"] = cmp.mapping(cycle_forward, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(cycle_backward, { "i", "s" }),
  },
  sources = {
    -- { name = "ultisnips" },
    { name = "nvim_lua" },
    { name = "nvim_lsp" },
    { -- buffer
      name = "buffer",
      opts = {
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
    priority_weight = 1,
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
        -- ultisnips = "[Snippet]",
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
  },
})
