-- Rex's copy mode (dotfiles/rex/.config/rex/scrollback.lua) opens a pane's scrollback in this
-- Neovim, floating over the pane: vim motions, search and visual mode select text, and any yank
-- copies to the clipboard and closes it, as q does. The text can be edited, and saved with :w as a
-- scratch file in /tmp. after/ftplugin/scrollback.lua and syntax/scrollback.lua set up the buffer.
local M = {}

-- Refocuses the pane copy mode was opened from, as a detached `rex do` script: only once the float
-- is gone, as the app focuses a closing float again and sends it the next keys.
local refocus_script = [[
local float, origin = %q, %q
local labels
for _ = 1, 250 do
  labels = {}
  for _, block in ipairs(assert(rex.session.list_blocks({})).blocks) do
    labels[block.block_id] = block.label
  end
  if labels[float] == nil then
    break
  end
  rex.sleep(0.02)
end

-- Leave the focus to a copy mode opened again meanwhile.
local view = assert(rex.session.view({}))
for _, window in ipairs(view.windows) do
  local in_copy_mode = labels[window.focused_block_id] == "copy mode"
  if window.window_id == view.active_window_id and in_copy_mode then
    return
  end
end
rex.session.focus_block({ block_id = origin })
]]

-- Shows the text where the pane shows it, with the cursor on the last line: the last line on the
-- pane cursor's row. The alternate screen of a full-screen program has no scrollback, so its text
-- is the screen, from the top. The float starts at the pane's size, so the window has its rows.
local function place_text(cursor_row, alternate)
  if alternate then
    vim.cmd("normal! ggG")
  elseif cursor_row == nil then
    vim.cmd("normal! Gzb")
  else
    -- From the last line at the top, scroll back to put it on the cursor's row.
    vim.cmd("normal! Gzt")
    if cursor_row > 1 then
      vim.cmd(("normal! %d\25"):format(cursor_row - 1)) -- ctrl+y
    end
  end

  -- Should the window be shorter than the cursor's row, scrolling back moved the cursor up.
  vim.cmd("normal! G")
end

-- Opens copy mode in the current buffer. `opts.path` holds the scrollback until read; `opts.origin`
-- is the pane copy mode was opened from; `opts.cursor_row` is the row of that pane's cursor, or
-- nil; `opts.alternate` tells whether the pane shows the alternate screen.
function M.open(opts)
  -- Setting the buffer's lines rather than giving the file as Neovim's argument skips the plugins
  -- that load on reading a file, which cut startup by two thirds. Deleted once read, the file
  -- exists again only if saved, which naming the buffer after it allows without overwrite warnings.
  local lines = vim.fn.readfile(opts.path)
  vim.fn.delete(opts.path)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(0, opts.path)
  vim.bo.swapfile = false
  vim.bo.modified = false

  -- autocmds.lua saves a view of every named buffer: none for scratch files, which would pile up.
  pcall(vim.api.nvim_del_augroup_by_name, "Views")

  vim.bo.filetype = "scrollback"

  -- No line of Neovim's own, so the text keeps the pane's rows.
  vim.opt.fillchars:append({ eob = " " })
  vim.o.cmdheight = 0
  -- Without a command line, any message asks to press Enter: show messages for a while instead.
  vim.o.messagesopt = vim.o.messagesopt:gsub("hit%-enter", "wait:1500")
  vim.o.showtabline = 0
  pcall(function()
    require("lualine").hide({ unhide = false })
  end)
  vim.o.laststatus = 0

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      place_text(opts.cursor_row, opts.alternate)
    end,
  })

  -- A background darker than the terminal's tells copy mode from the pane under it, which a float
  -- without a background of its own would also show through.
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  normal.bg = 0x242933 -- darker than Nord's #2e3440, the terminal's background in Rex's theme
  vim.api.nvim_set_hl(0, "Normal", normal)

  -- Rex exports the directory of its CLI, which only the interactive zsh puts on the PATH.
  local rex = vim.env.REX_BIN_DIR and vim.env.REX_BIN_DIR .. "/rex" or "rex"
  local refocus = refocus_script:format(vim.env.REX_BLOCK, opts.origin)
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      vim.fn.jobstart({ rex, "do", "-s", vim.env.REX_SESSION, "-e", refocus }, { detach = true })
    end,
  })

  -- Exit 0 even after :cq: the app keeps a terminal whose program failed open for a while, and
  -- sends it the keys meant to open copy mode again. VimLeave comes last, once all is saved.
  vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
      if vim.v.exiting ~= 0 then
        os.exit(0)
      end
    end,
  })

  -- Without nowait, global mappings such as `q:` delay q by timeoutlen, while Rex keeps sending
  -- keys to the float.
  vim.keymap.set("n", "q", "<cmd>qa!<cr>", { buffer = true, nowait = true })

  -- Only yanks: deleting and changing text also fire TextYankPost.
  vim.api.nvim_create_autocmd("TextYankPost", {
    buffer = 0,
    callback = function()
      if vim.v.event.operator ~= "y" then
        return
      end

      vim.fn.setreg("+", vim.v.event.regcontents, vim.v.event.regtype)
      vim.schedule(function()
        vim.cmd("qa!")
      end)
    end,
  })
end

return M
