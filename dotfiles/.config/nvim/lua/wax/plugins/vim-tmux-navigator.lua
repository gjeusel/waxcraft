-- tmux, disable tmux navigator when zooming the Vim pane
vim.g.tmux_navigator_disable_when_zoomed = 1

local modes = { "n", "i", "v", "c" }
local map_keymaps = {
  ["<c-j>"] = "TmuxNavigateDown",
  ["<c-k>"] = "TmuxNavigateUp",
  ["<c-l>"] = "TmuxNavigateLeft",
  ["<c-h>"] = "TmuxNavigateRight",
}

local opts = { silent = true, expr = true, remap = true }
for map, cmd in ipairs(map_keymaps) do
  vim.keymap.set(modes, map, function()
    vim.cmd(cmd)
  end, opts)
end
