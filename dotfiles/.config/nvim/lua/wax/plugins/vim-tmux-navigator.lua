-- tmux, disable tmux navigator when zooming the Vim pane
vim.g.tmux_navigator_disable_when_zoomed = 1
vim.g.tmux_navigator_no_mappings = 1 -- custom ones below regarding modes

-- local modes = { "n", "v", "c", "i", "s" }
local modes = { "n", "c" } -- other modes are handled in luasnip
local map_keymaps = {
  ["<c-j>"] = "TmuxNavigateDown",
  ["<c-k>"] = "TmuxNavigateUp",
  ["<c-l>"] = "TmuxNavigateRight",
  ["<c-h>"] = "TmuxNavigateLeft",
}

local opts = { silent = true, nowait = true, remap = true, expr = true }
for map, cmd in pairs(map_keymaps) do
  vim.keymap.set(modes, map, function()
    vim.cmd(cmd)
  end, opts)
end
