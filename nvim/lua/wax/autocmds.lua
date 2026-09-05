local utils = require("wax.utils")

-- Views contain window-local fold state, so each restore belongs to one
-- buffer/window visit. Leaving before parsing finishes must not save empty folds.
local group_view = vim.api.nvim_create_augroup("Views", { clear = true })
local pending_views = {}

local function can_initialize_folds(buf, win)
  return vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_buf(win) == buf
    and vim.bo[buf].buftype == ""
    and not vim.wo[win].diff
    and not is_big_file(vim.api.nvim_buf_get_name(buf))
end

local function has_view_name(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and not name:find("://")
end

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group_view,
  desc = "Load view after folds are ready",
  callback = function(opts)
    local buf, win = opts.buf, vim.api.nvim_get_current_win()
    if not can_initialize_folds(buf, win) then
      return
    end
    local request = {}
    pending_views[win] = request

    -- Run after startup's FileType/VimEnter fold-cache invalidation.
    vim.schedule(function()
      if pending_views[win] ~= request or not can_initialize_folds(buf, win) then
        return
      end
      local function restore_view()
        if pending_views[win] ~= request or not can_initialize_folds(buf, win) then
          return
        end
        vim.api.nvim_win_call(win, function()
          if
            vim.wo.foldmethod == "expr" and vim.wo.foldexpr == "v:lua.vim.treesitter.foldexpr()"
          then
            -- Populate C's window folds from the now-ready Tree-sitter tree
            -- before loadview replays its manually opened/closed folds.
            vim.wo.foldmethod = "expr"
          end
          -- Unnamed/URI buffers still need folds, but have no persistent view.
          if has_view_name(buf) then
            vim.cmd("silent! loadview")
          end
        end)
        if pending_views[win] == request then
          pending_views[win] = nil
        end
      end

      if
        vim.wo[win].foldmethod == "expr"
        and vim.wo[win].foldexpr == "v:lua.vim.treesitter.foldexpr()"
      then
        local ok, parser = pcall(vim.treesitter.get_parser, buf)
        if ok and parser then
          parser:parse(nil, function(_, trees)
            if trees then
              vim.schedule(restore_view)
            end
            -- On timeout, retain the pending marker to protect the saved view.
          end)
          return
        end
      end
      restore_view()
    end)
  end,
})
vim.api.nvim_create_autocmd({ "BufWritePost", "BufWinLeave" }, {
  group = group_view,
  desc = "Save view",
  callback = function(opts)
    local win = vim.api.nvim_get_current_win()
    local pending = pending_views[win]
    if opts.event == "BufWinLeave" then
      pending_views[win] = nil
    end
    if pending or not can_initialize_folds(opts.buf, win) or not has_view_name(opts.buf) then
      return
    end
    vim.cmd("silent! mkview")
  end,
})

-- Diff: folds are noise in diff mode, keep everything unfolded.

-- OptionSet (below) doesn't fire for diff mode set at startup, so handle
-- command-line diffs (git difftool / nvim -d) here. Diffview windows and the
-- post-save refold are handled by the diff_buf_win_enter hook in plugcfg/diffview.lua.
vim.api.nvim_create_autocmd("VimEnter", {
  desc = "Disable folds for diff mode started at launch",
  callback = function()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.wo[win].diff then
        vim.wo[win].foldenable = false
      end
    end
  end,
})

-- Handles runtime :diffthis and, crucially, re-enables folds when diff is turned off.
vim.api.nvim_create_autocmd("OptionSet", {
  desc = "Toggle folds & views as diff mode is entered/left",
  pattern = "diff",
  callback = function()
    local entering = vim.v.option_new == true -- v:option_new is a boolean for boolean options
    -- View callbacks skip diff windows; viewoptions/viewdir are global options.
    -- neovim restores foldmethod itself on exit
    vim.wo.foldenable = not entering
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
