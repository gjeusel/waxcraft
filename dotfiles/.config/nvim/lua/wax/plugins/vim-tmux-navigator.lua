-- All the other modes
local modes = ""
noremap(modes, "<c-j>", "<c-\\><c-n><c-w>j")
noremap(modes, "<c-k>", "<c-\\><c-n><c-w>k")
noremap(modes, "<c-h>", "<c-\\><c-n><c-w>h")
noremap(modes, "<c-l>", "<c-\\><c-n><c-w>l")


-- Normal Mode
nnoremap("<c-j>", "<c-w>j")
nnoremap("<c-k>", "<c-w>k")
nnoremap("<c-h>", "<c-w>h")
nnoremap("<c-l>", "<c-w>l")


-- tmux, disable tmux navigator when zooming the Vim pane
vim.g.tmux_navigator_disable_when_zoomed = 1
