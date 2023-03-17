local diffview = require("diffview")
local actions = require("diffview.actions")

local global_keymaps = {
  ["<C-n>"] = actions.select_next_entry, -- Open the diff for the next file
  ["<C-p>"] = actions.select_prev_entry, -- Open the diff for the previous file
  ["<leader>e"] = actions.focus_files, -- Bring focus to the file panel
  ["<leader>b"] = actions.toggle_files, -- Toggle the file panel.
  ["[x"] = actions.prev_conflict, -- In the merge_tool: jump to the previous conflict
  ["]x"] = actions.next_conflict, -- In the merge_tool: jump to the next conflict
}

diffview.setup({
  view = {
    default = {
      -- Config for changed files, and staged files in diff views.
      layout = "diff2_horizontal",
    },
    merge_tool = {
      -- Config for conflicted files in diff views during a merge or rebase.
      layout = "diff3_horizontal",
      disable_diagnostics = true, -- Temporarily disable diagnostics for conflict buffers while in the view.
    },
    file_history = {
      -- Config for changed files in file history views.
      layout = "diff2_horizontal",
    },
  },
  -- hooks = {
  --   diff_buf_read = function(_)
  --     -- vim.defer_fn(function()
  --     --   actions.focus_entry()
  --     --   actions.toggle_files()
  --     -- end, 1000)
  --   end,
  -- }, -- See ':h diffview-config-hooks'
  keymaps = {
    disable_defaults = true, -- Disable the default keymaps
    view = vim.tbl_extend("keep", global_keymaps, {
      -- The `view` bindings are active in the diff buffers, only when the current tabpage is a Diffview.
      ["<leader>co"] = actions.conflict_choose("ours"), -- Choose the OURS version of a conflict
      ["<leader>ct"] = actions.conflict_choose("theirs"), -- Choose the THEIRS version of a conflict
      ["<leader>cb"] = actions.conflict_choose("base"), -- Choose the BASE version of a conflict
      ["<leader>ca"] = actions.conflict_choose("all"), -- Choose all the versions of a conflict
      ["dx"] = actions.conflict_choose("none"), -- Delete the conflict region
    }),
    diff2 = global_keymaps,
    diff3 = vim.tbl_extend("keep", global_keymaps, {
      -- Mappings in 3-way diff layouts
      { { "n", "x" }, "2do", actions.diffget("ours") }, -- Obtain the diff hunk from the OURS version of the file
      { { "n", "x" }, "3do", actions.diffget("theirs") }, -- Obtain the diff hunk from the THEIRS version of the file
    }),
    file_panel = vim.tbl_extend("keep", global_keymaps, {
      ["j"] = actions.next_entry, -- Bring the cursor to the next file entry
      ["k"] = actions.prev_entry, -- Bring the cursor to the previous file entry.
      ["<cr>"] = actions.select_entry, -- Open the diff for the selected entry.
      ["<c-b>"] = actions.scroll_view(-0.25), -- Scroll the view up
      ["<c-f>"] = actions.scroll_view(0.25), -- Scroll the view down
      --
      ["-"] = actions.toggle_stage_entry, -- Stage / unstage the selected entry.
      ["S"] = actions.stage_all, -- Stage all entries.
      ["U"] = actions.unstage_all, -- Unstage all entries.
      ["X"] = actions.restore_entry, -- Restore entry to the state on the left side.
      ["L"] = actions.open_commit_log, -- Open the commit log panel.
      ["i"] = actions.listing_style, -- Toggle between 'list' and 'tree' views
      ["R"] = actions.refresh_files, -- Update stats and entries in the file list.
    }),
    file_history_panel = vim.tbl_extend("keep", global_keymaps, {
      ["j"] = actions.next_entry, -- Bring the cursor to the next file entry
      ["k"] = actions.prev_entry, -- Bring the cursor to the previous file entry.
      ["<cr>"] = actions.select_entry, -- Open the diff for the selected entry.
      ["<c-b>"] = actions.scroll_view(-0.25),
      ["<c-f>"] = actions.scroll_view(0.25),
      --
      ["g!"] = actions.options, -- Open the option panel
      -- ["<C-A-d>"] = actions.open_in_diffview, -- Open the entry under the cursor in a diffview
      -- ["gf>"] = actions.open_in_diffview, -- Open the entry under the cursor in a diffview
      ["y"] = actions.copy_hash, -- Copy the commit hash of the entry under the cursor
      ["L"] = actions.open_commit_log,
      ["zR"] = actions.open_all_folds,
      ["zM"] = actions.close_all_folds,
    }),
    option_panel = {
      ["<cr>"] = actions.select_entry,
      ["q"] = actions.close,
    },
  },
})

vim.keymap.set("n", "<leader>gg", "<cmd>DiffviewClose<cr>")
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>")

vim.keymap.set("n", "<leader>gf", function()
  -- vim.cmd("<cmd>DiffviewOpen HEAD %<cr>")
  diffview.open("HEAD", "%")
  -- diffview.
  -- actions.focus_entry()
end)
vim.keymap.set("n", "<leader>gm", function ()
  diffview.open("master", "%")
end)
