-- Handle Views
local group_view = "Views"
vim.api.nvim_create_augroup(group_view, { clear = true })
vim.api.nvim_create_autocmd("BufRead", { pattern = "*", command = "silent! loadview" })
vim.api.nvim_create_autocmd(
  { "BufWrite", "BufLeave" },
  { pattern = "*", command = "silent! mkview" }
)

------------- Local Settings depending on FileType -------------
--
local group_ft_settings = "FileType Local Settings"
vim.api.nvim_create_augroup(group_ft_settings, { clear = true })

local map_ft_local_settings = {
  yaml = "shiftwidth=2 tabstop=2 softtabstop=2 foldminlines=3",
  gitcommit = "spell viewoptions= viewdir=",
  git = "syntax=on nofoldenable",
  vim = "tabstop=2 foldmethod=marker",
  ["*sh"] = "nofoldenable",
  markdown = "spell textwidth=140 nofoldenable", -- "wrap wrapmargin=2"
  toml = "textwidth=140 nofoldenable",
  json = "foldmethod=syntax",
  edgeql = "commentstring=#%s",
  lua = "foldlevel=99",
  --
  python = "shiftwidth=4 tabstop=4 softtabstop=4",
  --
  html = "foldmethod=syntax nowrap shiftwidth=2 tabstop=2 softtabstop=2",
  [{ "vue", "typescript", "typescriptreact", "javascript", "javascriptreact" }] = "foldminlines=3",
}

for filetype, settings in pairs(map_ft_local_settings) do
  vim.api.nvim_create_autocmd("FileType", {
    group = group_ft_settings,
    pattern = filetype,
    command = ("setlocal %s"):format(settings),
  })
end

local function insert_new_line_in_current_buffer(str, opts)
  local default_opts = { delta = 1 }
  opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)

  local pos = vim.api.nvim_win_get_cursor(0)
  local n_line = pos[1]

  local n_insert_line = n_line + opts.delta

  -- deduce indent for line:
  -- local filetype = vim.api.nvim_buf_get_option(0, "filetype")
  local use_treesitter = is_module_available("nvim-treesitter.indent")
    -- and not vim.tbl_contains({ "python" }, filetype)

  local space
  if use_treesitter then
    local ts_indent = require("nvim-treesitter.indent")
    local n_space = ts_indent.get_indent(n_insert_line)
    space = string.rep(" ", n_space)
  else
    local n_space = vim.fn.indent(n_line - opts.delta + 1)
    space = string.rep(" ", n_space)
  end

  local str_added = ("%s%s"):format(space, str)

  vim.api.nvim_buf_set_lines(0, n_insert_line - 1, n_insert_line - 1, false, { str_added })
  vim.api.nvim_win_set_cursor(0, { n_insert_line, pos[2] })
end

-- Python
vim.api.nvim_create_autocmd("FileType", {
  group = group_ft_settings,
  pattern = "python",
  callback = function()
    vim.keymap.set("n", "<leader>o", function()
      insert_new_line_in_current_buffer('__import__("pdb").set_trace()  # BREAKPOINT')
    end)
    vim.keymap.set("n", "<leader>O", function()
      insert_new_line_in_current_buffer(
        '__import__("pdb").set_trace()  # BREAKPOINT',
        { delta = 0 }
      )
    end)
  end,
})

-- Frontend
vim.api.nvim_create_autocmd("FileType", {
  group = group_ft_settings,
  pattern = { "vue", "typescript", "javascript", "typescriptreact", "javascriptreact" },
  callback = function()
    vim.keymap.set("n", "<leader>o", function()
      insert_new_line_in_current_buffer("debugger  // BREAKPOINT")
    end)
    vim.keymap.set("n", "<leader>O", function()
      insert_new_line_in_current_buffer("debugger  // BREAKPOINT", { delta = 0 })
    end)
  end,
})

------------- Performances -------------
-- https://www.reddit.com/r/neovim/comments/pz3wyc/comment/heyy4qf/?utm_source=share&utm_medium=web2x&context=3

vim.api.nvim_create_autocmd({ "BufReadPre", "FileReadPre" }, {
  pattern = "*",
  callback = function(opts)
    local bufnr = opts.buf
    local fpath = vim.api.nvim_buf_get_name(bufnr)
    if not is_big_file(fpath) then
      return
    end

    local fname = vim.fn.expand("%:t")
    print(("Big file '%s', disabling features for performance reasons."):format(fname))

    -- Ensure syntax is disable
    vim.opt_local.syntax = nil

    -- disable folding
    vim.opt_local.foldmethod = "manual"
    vim.opt_local.foldexpr = nil

    -- disable view backup and swap
    vim.opt_local.backupdir = nil
    vim.opt_local.viewdir = nil
    vim.opt_local.viewoptions = nil
    vim.opt_local.directory = nil

    -- disable wrap
    vim.opt_local.wrap = nil

    -- vim.cmd([[setlocal noloadplugins]])
    -- vim.opt_local.noloadplugins = true

    -- disable all autocmds
    vim.opt_local.eventignore = "all"

    -- -- disable treesitter capabilities
    -- if is_module_available("nvim-treesitter") then
    --   local tsconfig = require("nvim-treesitter.configs")
    --   local ts_module_names = {
    --     "autotag",
    --     "indent",
    --     "incremental_selection",
    --     "context_commentstring",
    --     "autopairs",
    --     -- "highlight",
    --   }
    --   for _, module_name in ipairs(ts_module_names) do
    --     local module = tsconfig.get_module(module_name)
    --     if module and module.enabled_buffers then
    --       module.enabled_buffers[opts.buf] = false
    --     end
    --     tsconfig.detach_module(module_name, opts.buf)
    --   end
    -- end
  end,
})
