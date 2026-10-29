-- Rex's copy mode (dotfiles/rex/.config/rex/scrollback.lua) opens a snapshot of a pane's scrollback
-- in a Neovim without the user's init.lua or plugins, its UI attached once set up, floating over
-- the pane and showing the text where the pane does: vim motions, search and visual mode select
-- text, y copies to the clipboard, q quits, and ctrl+h/j/k/l move to the pane on that side, leaving
-- copy mode open. The text can be edited, and saved with :w as a scratch file in /tmp.
-- after/ftplugin/scrollback.lua and syntax/scrollback.lua set up the buffer.
local M = {}

-- Run detached as Neovim quits: focuses the pane copy mode was opened from rather than the one Rex
-- picks once the float closes. Only once the float is gone, as the app focuses a closing float
-- again and sends it the next keys.
local refocus_script = [[
local float, origin = %q, %q

local function labels()
  local result = {}
  for _, block in ipairs(assert(rex.session.list_blocks({})).blocks) do
    result[block.block_id] = block.label
  end

  return result
end

-- Waiting a second at a time covers the float closing before the wait starts.
while labels()[float] ~= nil do
  rex.wait("block_closed", { block_id = float }, 1)
end

-- Leave the focus alone when another window is active, or a copy mode is focused again.
local current = labels()
local view = assert(rex.session.view({}))
for _, window in ipairs(view.windows) do
  local in_window = false
  for _, layer in ipairs(window.layers) do
    for _, block in ipairs(layer.blocks or {}) do
      in_window = in_window or block.block_id == origin
    end
  end

  local in_copy_mode = current[window.focused_block_id] == "copy mode"
  if in_window and window.window_id == view.active_window_id and not in_copy_mode then
    rex.session.focus_block({ block_id = origin })
  end
end
]]

-- The Nord colorscheme of the Neovim config, built with lush.nvim, which only lazy.nvim loads, on
-- copy mode's `background`, as #rrggbb.
local function colorscheme(background)
  local config = vim.fn.resolve(vim.fn.stdpath("config"))
  local lush = vim.fn.stdpath("data") .. "/lazy/lush.nvim"
  vim.opt.runtimepath:prepend({ lush, vim.fs.dirname(config) .. "/colorschemes/nord" })
  vim.o.termguicolors = true
  pcall(vim.cmd.colorscheme, "nord")

  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  normal.bg = tonumber(background:sub(2), 16)
  vim.api.nvim_set_hl(0, "Normal", normal)
end

-- Shows the text where the pane shows it, with the cursor on the last line. The float has fewer
-- rows than the pane, `pane_rows`, under its title bar: its rows line up with the pane's bottom
-- ones. The last line ends on the row of the pane's cursor, `cursor_row`. The alternate screen of a
-- full-screen program has no scrollback, so its text is the screen.
local function place_text(cursor_row, alternate, pane_rows)
  local hidden = pane_rows - vim.o.lines
  local last = vim.api.nvim_buf_line_count(0)
  if alternate then
    vim.fn.winrestview({ topline = math.min(hidden + 1, last), lnum = last })
  elseif cursor_row == nil then
    vim.cmd("normal! Gzb")
  else
    -- From the last line at the top, scroll back by screen rows to end it on the cursor's row.
    vim.cmd("normal! Gzt")
    local rows = vim.api.nvim_win_text_height(0, { start_row = last - 1, end_row = last - 1 }).all
    local back = cursor_row - hidden - rows
    if back > 0 then
      vim.cmd(("normal! %d\25"):format(back)) -- ctrl+y
    end
  end

  -- Should the window be shorter than the cursor's row, scrolling back moved the cursor up.
  vim.cmd("normal! G")
end

-- Opens copy mode in the current buffer. `opts.path` holds the scrollback, deleted once read;
-- `opts.origin` is the pane copy mode was opened from; `opts.cursor_row` is the row of that pane's
-- cursor, or nil; `opts.alternate` tells whether the pane shows the alternate screen;
-- `opts.background` is copy mode's background, as #rrggbb; `opts.rows` is the pane's height.
-- Neovim starts without a UI, at the float's size, which attaches once copy mode is set up: the
-- text is in place for the UI's first draw.
function M.open(opts)
  -- Named after the snapshot, the buffer can be saved with :w without overwrite warnings.
  local lines = vim.fn.readfile(opts.path)
  vim.fn.delete(opts.path)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(0, opts.path .. ".txt")
  vim.bo.swapfile = false
  vim.bo.undofile = false
  vim.bo.modified = false
  vim.bo.filetype = "scrollback"

  colorscheme(opts.background)

  -- No line of Neovim's own, so the text keeps the pane's rows.
  vim.o.laststatus = 0
  vim.o.showtabline = 0
  vim.o.cmdheight = 0
  vim.o.ruler = false
  vim.opt.fillchars:append({ eob = " " })
  vim.opt.shortmess:append("I")
  -- Without a command line, any message asks to press Enter: show messages for a while instead.
  vim.o.messagesopt = vim.o.messagesopt:gsub("hit%-enter", "wait:1500")

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      place_text(opts.cursor_row, opts.alternate, opts.rows)
    end,
  })

  -- wax.navigator moves from REX_BLOCK, the float: move from the pane under it instead, which Rex's
  -- `navigate` action then leaves (dotfiles/rex/.config/rex/init.lua). Coming back to that pane
  -- focuses copy mode again.
  local float = vim.env.REX_BLOCK
  vim.env.REX_BLOCK = opts.origin
  for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
    vim.keymap.set({ "n", "x" }, "<C-" .. key .. ">", function()
      require("wax.navigator").navigate(direction)
    end, { buffer = true })
  end

  -- Rex exports the directory of its CLI to terminals, not to the actions that open them.
  local rex = vim.env.REX_BIN_DIR and vim.env.REX_BIN_DIR .. "/rex" or "rex"
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      local script = refocus_script:format(float, opts.origin)
      local argv = { rex, "do", "-s", vim.env.REX_SESSION, "-b", opts.origin, "-e", script }
      vim.fn.jobstart(argv, { detach = true })
    end,
  })

  vim.keymap.set("n", "q", "<cmd>qa!<cr>", { buffer = true, nowait = true })

  -- Only yanks: deleting and changing text also fire TextYankPost. Without a command line, the
  -- highlight shows the copy rather than a message, which would wait.
  vim.api.nvim_create_autocmd("TextYankPost", {
    buffer = 0,
    callback = function()
      local event = vim.v.event
      if event.operator ~= "y" then
        return
      end

      vim.fn.setreg("+", event.regcontents, event.regtype)
      vim.hl.on_yank({ timeout = 200 })
    end,
  })
end

return M
