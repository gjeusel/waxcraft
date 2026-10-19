-- Move between Neovim splits, then on to the terminal multiplexer's panes from the edge split.
-- Replaces christoomey/vim-tmux-navigator and also supports Rex (https://www.superlogical.com/rex).
--
-- The multiplexer must forward ctrl+h/j/k/l to Neovim: tmux does so through the
-- vim-tmux-navigator tmux plugin (dotfiles/tmux/.tmux.conf), Rex through dotfiles/rex init.lua.
-- Both stay in a zoomed pane, as `tmux_navigator_disable_when_zoomed` did.

local M = {}

---@alias Wax.NavigatorDirection "left" | "down" | "up" | "right"

local wincmd_keys = { left = "h", down = "j", up = "k", right = "l" }
local tmux_flags = { left = "-L", down = "-D", up = "-U", right = "-R" }

-- Runs on the Rex server with `rex do -e`, which takes the block from REX_BLOCK.
local rex_script = [[
local view, err = rex.session.view({})
if view == nil then
  error(err, 0)
end

for _, window in ipairs(view.windows) do
  if window.zoomed_block_id == rex.block_id then
    return
  end
end

_, err = rex.session.focus_direction({ direction = rex.args.direction, wrap = true })
if err ~= nil then
  error(err, 0)
end
]]

---@param direction Wax.NavigatorDirection
---@return string[] | nil
local function multiplexer_command(direction)
  -- tmux first: when tmux runs inside Rex, it is the multiplexer closest to Neovim.
  if vim.env.TMUX then
    local pane = vim.env.TMUX_PANE
    local select = ("select-pane -t %s %s"):format(pane, tmux_flags[direction])

    return { "tmux", "if-shell", "-F", "-t", pane, "#{window_zoomed_flag}", "", select }
  end

  if vim.env.REX_BLOCK then
    -- REX_BIN_DIR holds the CLI matching the server, even when `rex` is not on PATH.
    local rex = vim.env.REX_BIN_DIR and vim.fs.joinpath(vim.env.REX_BIN_DIR, "rex") or "rex"
    if vim.fn.executable(rex) == 0 then
      rex = "rex"
    end

    return { rex, "do", "-e", rex_script, "direction=" .. direction }
  end

  return nil
end

---Focus the split in `direction`, or the multiplexer pane beyond it from the edge split.
---@param direction Wax.NavigatorDirection
function M.navigate(direction)
  local window = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(wincmd_keys[direction])
  if vim.api.nvim_get_current_win() ~= window then
    return
  end

  local command = multiplexer_command(direction)
  if command == nil then
    return
  end

  vim.system(command, { text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify("[wax.navigator] " .. vim.trim(result.stderr), vim.log.levels.WARN)
      end)
    end
  end)
end

return M
