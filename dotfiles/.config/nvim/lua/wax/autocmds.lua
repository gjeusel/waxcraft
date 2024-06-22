local utils = require("wax.utils")

-- Handle Views
local group_view = "Views"
vim.api.nvim_create_augroup(group_view, { clear = true })
vim.api.nvim_create_autocmd("BufRead", { pattern = "*", command = "silent! loadview" })
vim.api.nvim_create_autocmd(
  { "BufWrite", "BufLeave" },
  { pattern = "*", command = "silent! mkview" }
)

-- When in diffmode, open all folds
vim.cmd([[au OptionSet diff normal zR]])

-- Python
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.keymap.set("n", "<leader>o", function()
      utils.insert_new_line_in_current_buffer('__import__("pdb").set_trace()  # BREAKPOINT')
    end, {
      buffer = 0,
      desc = "Insert pdb breakpoint below.",
    })
    vim.keymap.set("n", "<leader>O", function()
      utils.insert_new_line_in_current_buffer(
        '__import__("pdb").set_trace()  # BREAKPOINT',
        { delta = 0 }
      )
    end, {
      buffer = 0,
      desc = "Insert pdb breakpoint above.",
    })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    local python = require("wax.lsp.python-utils").get_python_path()
    vim.g.python3_host_prog = python
  end,
})

-- Frontend
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "vue",
    "svelte",
    "typescript",
    "javascript",
    "typescriptreact",
    "javascriptreact",
    "html",
  },
  callback = function()
    vim.keymap.set("n", "<leader>o", function()
      utils.insert_new_line_in_current_buffer("debugger // BREAKPOINT")
    end, {
      buffer = 0,
      desc = "Insert debugger breakpoint below.",
    })
    vim.keymap.set("n", "<leader>O", function()
      utils.insert_new_line_in_current_buffer("debugger // BREAKPOINT", { delta = 0 })
    end, {
      buffer = 0,
      desc = "Insert debugger breakpoint above.",
    })
  end,
})

-- -- Fix Html like mini.ai
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = { "jinja.html", "html", "vue" },
--   callback = function()
--     -- Solve issue on mini ai with nested html tags
--     -- https://github.com/echasnovski/mini.nvim/issues/110
--     if is_module_available("mini.ai") then
--       local spec_treesitter = require("mini.ai").gen_spec.treesitter
--       vim.b.miniai_config = {
--         custom_textobjects = {
--           t = spec_treesitter({ a = "@function.outer", i = "@function.inner" }),
--         },
--       }
--     end
--   end,
-- })

-- -- Can't use after file for jinja.html filetype
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = { "jinja.html" },
--   callback = function()
--     -- vim.opt_local.commentstring = "{# %s #}"
--     -- vim.opt_local.comments = "{#"
--   end,
-- })

-- Performances
--
-- https://www.reddit.com/r/neovim/comments/pz3wyc/comment/heyy4qf/?utm_source=share&utm_medium=web2x&context=3
vim.api.nvim_create_autocmd({ "BufReadPre", "FileReadPre" }, {
  pattern = "*",
  callback = function(opts)
    local fpath = opts.match
    if not is_big_file(fpath) then
      return
    end

    local fname = vim.fn.expand("%:t")
    vim.schedule(function()
      print("big file detected -> minimalist mode")
    end)

    -- Ensure syntax is disable
    vim.opt_local.syntax = nil

    -- disable folding
    vim.opt_local.foldmethod = "indent"
    vim.opt_local.foldexpr = nil

    -- disable view backup and swap
    vim.opt_local.backupdir = nil
    -- vim.opt_local.viewdir = nil
    vim.opt_local.viewoptions = nil
    vim.opt_local.directory = nil

    -- disable wrap
    vim.opt_local.wrap = nil

    -- disable indentline
    vim.b.miniindentscope_disable = true

    -- disable undotree
    vim.b.loaded_undotree = 1

    -- vim.cmd([[setlocal noloadplugins]])
    -- vim.opt_local.noloadplugins = true

    -- disable all autocmds
    -- vim.opt_local.eventignore = "all"

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
