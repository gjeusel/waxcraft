local utils = require("wax.utils")

-- Handle Views
local group_view = "Views"
vim.api.nvim_create_augroup(group_view, { clear = true })
vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  desc = "Load view",
  pattern = "*",
  callback = function(opts)
    if vim.bo[opts.buf].buftype ~= "" then return end
    local name = vim.api.nvim_buf_get_name(opts.buf)
    if name == "" or name:find("://") then return end
    vim.cmd("silent! loadview")
  end,
})
vim.api.nvim_create_autocmd({ "BufWrite", "BufLeave" }, {
  desc = "Save view",
  pattern = "*",
  callback = function(opts)
    if vim.bo[opts.buf].buftype ~= "" then return end
    local name = vim.api.nvim_buf_get_name(opts.buf)
    if name == "" or name:find("://") then return end
    vim.cmd("silent! mkview")
  end,
})

-- Diff
local previous_foldmethod = nil

vim.api.nvim_create_autocmd("OptionSet", {
  desc = "Disable folds & views in diff buffers",
  pattern = "diff",
  callback = function()
    if vim.opt.diff then
      vim.opt_local.viewoptions = nil
      vim.opt_local.viewdir = nil

      vim.opt_local.foldenable = false

      previous_foldmethod = vim.opt.foldmethod
    elseif previous_foldmethod then
      vim.opt.foldmethod = previous_foldmethod -- set back previous foldmethod when leaving diff mode
      previous_foldmethod = nil
    end
  end,
})

-- Frontend keymaps
vim.api.nvim_create_autocmd("FileType", {
  desc = "Add keymaps for debugger breakpoints for frontend files",
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

-- Performances
--
-- https://www.reddit.com/r/neovim/comments/pz3wyc/comment/heyy4qf/?utm_source=share&utm_medium=web2x&context=3
vim.api.nvim_create_autocmd({ "BufReadPre", "FileReadPre" }, {
  desc = "Optimize performances in big files",
  pattern = "*",
  callback = function(opts)
    local fpath = opts.match
    if not is_big_file(fpath) then
      return
    end

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
