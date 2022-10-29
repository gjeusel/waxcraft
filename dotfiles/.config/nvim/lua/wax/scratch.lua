-- Credits to:
-- https://github.com/is0n/jaq-nvim

local M = {}

local config = {
  cmds = {
    -- Uses vim commands
    internal = {
      lua = "luafile %",
      vim = "source %",
    },
    -- Uses shell commands
    external = {
      markdown = "glow %",
      python = "python3 %",
      go = "go run %",
      sh = "sh %",
    },
  },
  behavior = {
    default = "float",
    startinsert = true,
    wincmd = false,
    autosave = false,
  },
  ui = {
    float = {
      border = "rounded",
      winhl = "Normal",
      borderhl = "FloatBorder",
      height = 0.7,
      width = 0.7,
      x = 0.5,
      y = 0.5,
      winblend = 0,
    },
    terminal = {
      position = "bot",
      line_no = false,
      size = 10,
    },
    quickfix = {
      position = "bot",
      size = 10,
    },
  },
}

local function dimensions(opts)
  local cl = vim.o.columns
  local ln = vim.o.lines

  local width = math.ceil(cl * opts.ui.float.width)
  local height = math.ceil(ln * opts.ui.float.height - 4)

  local col = math.ceil((cl - width) * opts.ui.float.x)
  local row = math.ceil((ln - height) * opts.ui.float.y - 1)

  return {
    width = width,
    height = height,
    col = col,
    row = row,
  }
end

local function resize()
  local dim = dimensions(config)
  vim.api.nvim_win_set_config(M.win, {
    style = "minimal",
    relative = "editor",
    border = config.ui.float.border,
    height = dim.height,
    width = dim.width,
    col = dim.col,
    row = dim.row,
  })
end

function M.float_win()
  local dim = dimensions(config)

  local bufnr = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    anchor = "NW",
    style = "minimal",
    width = dim.width,
    col = dim.col,
    row = dim.row,
    border = config.ui.float.border,
    height = dim.height,
    -- noautocmd = true,
  })

  -- Handle auto-resize
  vim.api.nvim_create_autocmd("VimResized", {
    pattern = "*",
    callback = resize,
    buffer = bufnr,
    desc = "Auto resize floating window",
  })

  -- Handle auto closing on WinLeave
  local close = function()
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  vim.api.nvim_create_autocmd("WinLeave", { callback = close, buffer = bufnr })

  -- Add custom mappings
  local mappings = {
    n = {
      q = close,
      ["<ESC>"] = close,
    },
  }

  for mode, maps in pairs(mappings) do
    for k, v in pairs(maps) do
      if type(v) == "string" then
        vim.api.nvim_buf_set_keymap(bufnr, mode, k, v, { nowait = true })
      else
        vim.api.nvim_buf_set_keymap(bufnr, mode, k, "", { callback = v, nowait = true })
      end
    end
  end

  vim.api.nvim_win_set_option(win, "winhl", ("Normal:%s"):format(config.ui.float.winhl))
  vim.api.nvim_win_set_option(win, "winhl", ("FloatBorder:%s"):format(config.ui.float.borderhl))
  vim.api.nvim_win_set_option(win, "winblend", config.ui.float.winblend)

  vim.api.nvim_buf_set_option(bufnr, "filetype", "scratch")

  return { bufnr = bufnr, win = win }
end

local function float(cmd)
  local floatopts = M.float_win()
  M.buf = floatopts.bufnr
  M.win = floatopts.win

  vim.fn.termopen(cmd, {
    detach = false,
    on_exit = function()
      log.warn("leaving this shit out")
    end,
  })

  if config.behavior.startinsert then
    vim.cmd("startinsert")
  end

  if config.behavior.wincmd then
    vim.cmd("wincmd p")
  end
end

local function term(cmd)
  vim.cmd(config.ui.terminal.position .. " " .. config.ui.terminal.size .. "new | term " .. cmd)

  M.buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_option(M.buf, "filetype", "Jaq")
  vim.api.nvim_buf_set_keymap(M.buf, "n", "<ESC>", "<cmd>:bdelete!<CR>", { silent = true })

  if config.behavior.startinsert then
    vim.cmd("startinsert")
  end

  if not config.ui.terminal.line_no then
    vim.cmd("setlocal nonumber | setlocal norelativenumber")
  end

  if config.behavior.wincmd then
    vim.cmd("wincmd p")
  end
end

local function quickfix(cmd)
  vim.cmd(
    'cex system("'
      .. cmd
      .. '") | '
      .. config.ui.quickfix.position
      .. " copen "
      .. config.ui.quickfix.size
  )

  if config.behavior.wincmd then
    vim.cmd("wincmd p")
  end
end

-- HUUUUUUUUUUUUUUUUUUUUUUUGE kudos and thanks to
-- https://github.com/hown3d for this function <3
local function substitute(cmd)
  cmd = cmd:gsub("%%", vim.fn.expand("%"))
  cmd = cmd:gsub("$fileBase", vim.fn.expand("%:r"))
  cmd = cmd:gsub("$filePath", vim.fn.expand("%:p"))
  cmd = cmd:gsub("$file", vim.fn.expand("%"))
  cmd = cmd:gsub("$dir", vim.fn.expand("%:p:h"))
  cmd = cmd:gsub(
    "$moduleName",
    vim.fn.substitute(
      vim.fn.substitute(vim.fn.fnamemodify(vim.fn.expand("%:r"), ":~:."), "/", ".", "g"),
      "\\",
      ".",
      "g"
    )
  )
  cmd = cmd:gsub("#", vim.fn.expand("#"))
  cmd = cmd:gsub("$altFile", vim.fn.expand("#"))

  return cmd
end

local function internal(cmd)
  cmd = cmd or config.cmds.internal[vim.bo.filetype]

  if not cmd then
    vim.cmd("echohl ErrorMsg | echo 'Error: Invalid command' | echohl None")
    return
  end

  if config.behavior.autosave then
    vim.cmd("silent write")
  end

  cmd = substitute(cmd)
  vim.cmd(cmd)
end

local function run(type, cmd)
  cmd = cmd or config.cmds.external[vim.bo.filetype]

  if not cmd then
    vim.cmd("echohl ErrorMsg | echo 'Error: Invalid command' | echohl None")
    return
  end

  if config.behavior.autosave then
    vim.cmd("silent write")
  end

  cmd = substitute(cmd)
  if type == "float" then
    float(cmd)
    return
  elseif type == "bang" then
    vim.cmd("!" .. cmd)
    return
  elseif type == "quickfix" then
    quickfix(cmd)
    return
  elseif type == "terminal" then
    term(cmd)
    return
  end

  vim.cmd("echohl ErrorMsg | echo 'Error: Invalid type' | echohl None")
end

function M.Jaq(type)
  -- Check if the filetype is in config.cmds.internal
  if vim.tbl_contains(vim.tbl_keys(config.cmds.internal), vim.bo.filetype) then
    -- Exit if the type was passed and isn't "internal"
    if type and type ~= "internal" then
      vim.cmd("echohl ErrorMsg | echo 'Error: Invalid type for internal command' | echohl None")
      return
    end
    type = "internal"
  else
    type = type or config.behavior.default
  end

  if type == "internal" then
    internal()
    return
  end

  run(type)
end

--------- Mapping ---------
--
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "lua" },
  callback = function()
    vim.keymap.set("n", "<leader>fq", M.Jaq, { buffer = 0 })
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua" },
  callback = function()
    vim.keymap.set("v", "<leader>fq", function()
      -- waiting for lua "get_visual_selection"
      -- https://github.com/neovim/neovim/pull/13896
      vim.cmd([[normal! "ty]])
      local selection = vim.fn.getreg('t')

      -- -- Pulled from luaeval function
      -- local chunkheader = "local _A = select(1, ...) return "
      -- local result = loadstring(chunkheader .. selection, "debug")()
      local result = loadstring(selection, "scratch")()

      if result then
        vim.notify("TODO: implement float win. For now:\n" .. vim.inspect(result))
        -- local content = { selection, "", vim.inspect(result) }
        -- local floatopts = M.float_win()
        -- open_scratch_win(content)
      end
    end, {
      buffer = 0,
    })
  end,
})

return M
