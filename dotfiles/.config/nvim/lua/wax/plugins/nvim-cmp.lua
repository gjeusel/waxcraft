local cmp = require("cmp")

local check_back_space = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col == 0 or vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
    :sub(col, col)
    :match("%s") ~= nil
end

cmp.setup({
  snippet = {
    expand = function(args)
      vim.fn["UltiSnips#ExpandSnippet"](args.body)
    end,
  },
  mapping = {
    ["<C-y>"] = cmp.mapping.confirm({ select = true }),
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.close(),
    ["<CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    }),
    ["<Tab>"] = function(fallback)
      if vim.fn.pumvisible() == 1 then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, true, true), "n", true)
      elseif check_back_space() then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, true, true), "n", true)
        -- elseif vim.fn["vsnip#available"]() == 1 then
        --   vim.api.nvim_feedkeys(
        --     vim.api.nvim_replace_termcodes("<Plug>(vsnip-expand-or-jump)", true, true, true),
        --     "",
        --     true
        --   )
      else
        fallback()
      end
    end,
  },
  sources = {
    { name = "buffer" },
    { name = "path" },
    { name = "nvim_lua" },
    { name = "nvim_lsp" },
    -- { name = "treesitter" },
  },
})
