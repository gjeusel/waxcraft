local cmp = require("cmp")
local lspkind = require("lspkind")

local luasnip = safe_require("luasnip")

local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0
    and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end
local cycle_forward = function(fallback)
  if cmp.visible() then
    cmp.select_next_item({ behavior = cmp.SelectBehavior.Inserts })
  elseif has_words_before() then
    cmp.complete()
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

local function get_visible_buffers()
  local bufs = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    bufs[vim.api.nvim_win_get_buf(win)] = true
  end
  return vim.tbl_keys(bufs)
end

cmp.setup({
  completion = {
    keyword_length = 1,
  },
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
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
    {
      name = "rg",
      keyword_length = 3,
      max_item_count = 5,
      option = {
        -- only trigger rg if find a git workspace
        cwd = function()
          local cwd = find_root_dir()
          if cwd == vim.env.HOME then
            return nil
          else
            return cwd
          end
        end,
      },
    },
    { -- buffer
      name = "buffer",
      keyword_length = 3,
      max_item_count = 5,
      options = { get_bufnrs = get_visible_buffers },
    },
    -- { name = "nvim_lsp_signature_help" },
    -- { name = "copilot", max_item_count = 3, keyword_length = 5 },
    { name = "path" },
    -- { name = "treesitter" },
  },
  sorting = {
    priority_weight = 1000,
    comparators = {
      -- require("copilot_cmp.comparators").prioritize,
      -- require("copilot_cmp.comparators").score,

      cmp.config.compare.score,
      cmp.config.compare.offset,
      cmp.config.compare.recently_used,
      cmp.config.compare.scopes, --this is commented in nvim-cmp too
      cmp.config.compare.exact,
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
        rg = "[RipG]",
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
    -- completion = vim.tbl_extend("force", cmp.config.window.bordered(), {
    --   border = "single",
    --   maxwidth = 100,
    --   max_height = 3,
    --   winblend = 0,
    -- }),
    documentation = {
      maxwidth = 80,
      max_height = math.floor(vim.o.lines * 0.3),
      border = "rounded",
      winblend = 0,
    },
  },
})
