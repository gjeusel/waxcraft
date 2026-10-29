-- A terminal's scrollback, as Rex's copy mode shows it (lua/wax/copy_mode.lua).
-- Commands start at pure's prompt line, `λ cmd`, after the virtualenv's name when one is active.
-- syntax/scrollback.lua highlights them.

local prompt = [[^\(\S\+ \)\?λ]]

-- Show the text as the terminal does: no columns of Neovim's own, and long lines wrapped at the
-- window's width onto the rows they had.
vim.opt_local.number = false
vim.opt_local.relativenumber = false
vim.opt_local.signcolumn = "no"
vim.opt_local.foldcolumn = "0"
vim.opt_local.statuscolumn = ""
vim.opt_local.colorcolumn = ""
vim.opt_local.list = false
vim.opt_local.wrap = true
vim.opt_local.linebreak = false
vim.opt_local.breakindent = false
vim.opt_local.showbreak = "NONE"
-- Scroll by screen rows, keeping wrapped lines where the terminal shows them, up to the edges.
vim.opt_local.smoothscroll = true
vim.opt_local.scrolloff = 0
vim.b.miniindentscope_disable = true

-- j and k move by screen rows, as wrapped lines take several.
vim.keymap.set({ "n", "x" }, "j", "gj", { buffer = true })
vim.keymap.set({ "n", "x" }, "k", "gk", { buffer = true })

-- Whether line `lnum`, matching `prompt`, follows a preprompt line, itself after a blank line or at
-- the top: output lines with a `λ` rarely do.
local function is_prompt(lnum)
  local preprompt = vim.fn.getline(lnum - 1)
  local above_blank = lnum == 2 or vim.fn.getline(lnum - 2) == ""

  return lnum > 1 and preprompt ~= "" and above_blank
end

-- [[ and ]] jump to the previous or next command.
for key, flags in pairs({ ["[["] = "bW", ["]]"] = "W" }) do
  local jump = function()
    local view = vim.fn.winsaveview()
    local lnum
    repeat
      lnum = vim.fn.search(prompt, flags)
    until lnum == 0 or is_prompt(lnum)

    if lnum == 0 then
      vim.fn.winrestview(view)
    end
  end
  vim.keymap.set({ "n", "x", "o" }, key, jump, { buffer = true })
end
