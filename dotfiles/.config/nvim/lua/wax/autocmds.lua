local utils = require("wax.utils")

-- Handle Views
local group_view = "Views"
vim.api.nvim_create_augroup(group_view, { clear = true })
vim.api.nvim_create_autocmd("BufRead", { pattern = "*", command = "silent! loadview" })
vim.api.nvim_create_autocmd(
  { "BufWrite", "BufLeave" },
  { pattern = "*", command = "silent! mkview" }
)

-- Python
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.keymap.set("n", "<leader>o", function()
      utils.insert_new_line_in_current_buffer('__import__("pdb").set_trace()  # BREAKPOINT')
    end, {
      desc = "Insert pdb breakpoint below.",
    })
    vim.keymap.set("n", "<leader>O", function()
      utils.insert_new_line_in_current_buffer(
        '__import__("pdb").set_trace()  # BREAKPOINT',
        { delta = 0 }
      )
    end, {
      desc = "Insert pdb breakpoint above.",
    })
  end,
})

-- Frontend
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "vue", "typescript", "javascript", "typescriptreact", "javascriptreact" },
  callback = function()
    vim.keymap.set("n", "<leader>o", function()
      utils.insert_new_line_in_current_buffer("debugger  // BREAKPOINT")
    end, {
      desc = "Insert debugger breakpoint below.",
    })
    vim.keymap.set("n", "<leader>O", function()
      utils.insert_new_line_in_current_buffer("debugger  // BREAKPOINT", { delta = 0 })
    end, {
      desc = "Insert debugger breakpoint above.",
    })
  end,
})

-- Performances
--
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
