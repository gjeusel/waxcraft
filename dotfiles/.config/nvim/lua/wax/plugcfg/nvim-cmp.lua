local cmp = require("cmp")
local lspkind = require("lspkind")
local ls = safe_require("luasnip")

local function get_visible_buffers()
  local bufs = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    bufs[vim.api.nvim_win_get_buf(win)] = true
  end
  return vim.tbl_keys(bufs)
end

local function format(entry, vim_item)
  -- Special case of copilot
  if entry.source.name == "copilot" then
    vim_item.kind = "    AI"
    return vim_item
  end

  -- fancy icons and a name of kind
  if vim_item.kind then
    vim_item.kind = lspkind.presets.default[vim_item.kind] .. " " .. vim_item.kind
  end

  local lsp_client = ""
  if entry.source.name == "nvim_lsp" then
    lsp_client = ("[%s]"):format(entry.source.source.client.name)
  end

  -- set a name for each source
  vim_item.menu = ({
    nvim_lua = "[Lua]",
    rg = "[RipG]",
    buffer = "[Buffer]",
    nvim_lsp = lsp_client,
    path = "[Path]",
    luasnip = "[Snip]",
    copilot = "[AI]",
  })[entry.source.name]

  -- disable duplicate keys: https://github.com/hrsh7th/nvim-cmp/issues/32
  vim_item.dup = ({
    buffer = 0,
    path = 1,
    nvim_lsp = 0,
  })[entry.source.name] or 0

  -- set max width with abbr
  if string.len(vim_item.abbr) > 25 then
    vim_item.abbr = string.sub(vim_item.abbr, 1, 20) .. " ... "
  end
  return vim_item
end

local source_rg = {
  name = "rg",
  keyword_length = 3,
  max_item_count = 5,
  option = {
    -- only trigger rg if find a git workspace
    cwd = function()
      local cwd = find_root_dir(vim.api.nvim_buf_get_name(0))
      if cwd == vim.env.HOME then
        return nil
      else
        return cwd
      end
    end,
  },
}

local source_buffer = {
  -- buffer
  name = "buffer",
  keyword_length = 2,
  max_item_count = 5,
  options = { get_bufnrs = get_visible_buffers },
}

local cmp_select = { behavior = cmp.SelectBehavior.Select }

cmp.setup({
  completion = {
    keyword_length = 1,
    -- GH issue: "Accepted completion triggers new completion"
    -- https://github.com/hrsh7th/nvim-cmp/issues/1055
    get_trigger_characters = function(trigger_characters)
      local new_trigger_characters = {}
      for _, char in ipairs(trigger_characters) do
        if char ~= ">" then
          table.insert(new_trigger_characters, char)
        end
      end
      return new_trigger_characters
    end,
  },
  snippet = {
    expand = function(args)
      ls.lsp_expand(args.body)
    end,
  },
  mapping = {
    ["<Tab>"] = cmp.mapping.select_next_item(cmp_select),
    ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
    ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
    ["<C-y>"] = cmp.mapping.confirm({ select = true }),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<C-Space>"] = cmp.mapping.confirm({ select = true }),
    ["<C-d>"] = cmp.mapping.scroll_docs(4),
    ["<C-u>"] = cmp.mapping.scroll_docs(-4),
    ["<C-e>"] = cmp.mapping.close(),
    ["<C-c>"] = cmp.mapping(function()
      if cmp.visible() then
        cmp.close()
      end
      vim.cmd.stopinsert()
    end, { "i" }),
  },
  sources = {
    { name = "nvim_lua" },
    { name = "luasnip", keyword_length = 2, max_item_count = 2 },
    { name = "nvim_lsp", keyword_length = 1, max_item_count = 10 },
    source_buffer,
    source_rg,
    { name = "path" },
  },
  -- sorting = {
  --   priority_weight = 1000,
  --   comparators = {
  --     -- require("copilot_cmp.comparators").prioritize,
  --     -- require("copilot_cmp.comparators").score,

  --     cmp.config.compare.score,
  --     cmp.config.compare.offset,
  --     cmp.config.compare.recently_used,
  --     -- scopes is using treesitter
  --     -- cmp.config.compare.scopes, --this is commented in nvim-cmp too
  --     cmp.config.compare.exact,
  --     cmp.config.compare.locality,
  --     cmp.config.compare.kind,
  --     cmp.config.compare.sort_text,
  --     cmp.config.compare.length,
  --     cmp.config.compare.order,
  --   },
  -- },
  --
  sorting = {
    comparators = {
      cmp.config.compare.offset,
      cmp.config.compare.exact,
      cmp.config.compare.score,
      cmp.config.compare.recently_used,
      cmp.config.compare.order,
    },
  },
  formatting = { format = format },
  window = {
    documentation = {
      maxwidth = 80,
      max_height = math.floor(vim.o.lines * 0.3),
      border = "rounded",
      winblend = 0,
    },
  },
})

-- Completion in DAP buffers
cmp.setup({
  enabled = function()
    return vim.api.nvim_get_option_value("buftype", { buf = 0 }) ~= "prompt"
      or require("cmp_dap").is_dap_buffer()
  end,
})
cmp.setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
  enabled = true,
  sources = {
    { name = "dap" },
  },
})
