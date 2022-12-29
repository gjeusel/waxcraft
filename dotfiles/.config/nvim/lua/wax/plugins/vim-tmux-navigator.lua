-- tmux, disable tmux navigator when zooming the Vim pane
vim.g.tmux_navigator_disable_when_zoomed = 1
vim.g.tmux_navigator_no_mappings = 1 -- custom ones below regarding modes

local map_keymaps = {
  ["<c-j>"] = "TmuxNavigateDown",
  ["<c-k>"] = "TmuxNavigateUp",
  ["<c-l>"] = "TmuxNavigateRight",
  ["<c-h>"] = "TmuxNavigateLeft",
}

local opts = { silent = true, nowait = true, remap = true }

for map, cmd in pairs(map_keymaps) do
  vim.keymap.set("n", map, "<cmd>" .. cmd .. "<cr>", opts)
end

-- for _, map in ipairs(vim.tbl_keys(map_keymaps)) do
--   vim.keymap.set("i", map, "<nop>", opts)
-- end
