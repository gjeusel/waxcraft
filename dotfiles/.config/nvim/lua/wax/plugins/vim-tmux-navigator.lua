-- Normal Mode
nnoremap("<c-j>", "<c-w>j")
nnoremap("<c-k>", "<c-w>k")
nnoremap("<c-h>", "<c-w>h")
nnoremap("<c-l>", "<c-w>l")


-- All the other modes
local modes = "tic"
noremap(modes, "<c-j>", "<c-\\><c-n><c-w>j")
noremap(modes, "<c-k>", "<c-\\><c-n><c-w>k")
noremap(modes, "<c-h>", "<c-\\><c-n><c-w>h")
noremap(modes, "<c-l>", "<c-\\><c-n><c-w>l")
