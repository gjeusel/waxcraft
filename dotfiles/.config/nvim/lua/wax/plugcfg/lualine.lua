local Path = require("wax.path")

local relative_path = wax_cache_fn(function()
  local abspath = vim.api.nvim_buf_get_name(0)
  local workspace = find_root_dir(abspath, {
    "package.json", -- better in monorepo
    ".git",
  })
  workspace = workspace or vim.env.HOME

  local relpath = Path:new(abspath):make_relative(workspace)
  local path = relpath.path
  local name = to_workspace_name(workspace)
  if string.find(relpath.path, name) == nil then
    path = ("%s/%s"):format(name, relpath.path)
  end

  return path
end)

local workspace_name = wax_cache_fn(function()
  local name = find_workspace_name() or ""
  local relpath = relative_path()
  if string.find(relpath, name) ~= nil then
    return ""
  else
    return name
  end
end, {})

local function filetype()
  return vim.api.nvim_get_option_value(0, "filetype")
end

--- @param trunc_width number trunctates component when screen width is less then trunc_width
--- @param trunc_len number truncates component to trunc_len number of chars
--- @param hide_width number hides component when window width is smaller then hide_width
--- @param no_ellipsis boolean whether to disable adding '...' at end after truncation
--- return function that can format the component accordingly
local function trunc(trunc_width, trunc_len, hide_width, no_ellipsis)
  return function(str)
    local win_width = vim.fn.winwidth(0)
    if hide_width and win_width < hide_width then
      return ""
    elseif trunc_width and trunc_len and win_width < trunc_width and #str > trunc_len then
      return str:sub(1, trunc_len) .. (no_ellipsis and "" or "...")
    end
    return str
  end
end

local function fmt_mode(value)
  return "  " .. string.lower(value) .. string.rep(" ", 7 - #value)
end

local colors = {
  green = "#a89984",
  GruvboxFg4 = "#a89984",
  GruvboxBg0 = "#282828",
  GruvboxBg1 = "#3c3836",
  GruvboxBg3 = "#665c54",
}

local sober_theme = {
  a = { fg = colors.green, gui = "bold" },
  b = { fg = colors.GruvboxBg3 },
  c = { fg = colors.GruvboxBg3 },
  x = { fg = colors.GruvboxBg3 },
  y = { fg = colors.GruvboxBg3 },
  z = { fg = colors.GruvboxBg3 },
}

local function to_mode_theme(a_opts)
  return vim.tbl_extend("keep", { a = a_opts }, sober_theme)
end

local theme = {
  normal = to_mode_theme(),
  insert = to_mode_theme(),
  visual = to_mode_theme(),
  replace = to_mode_theme(),
  command = to_mode_theme(),
  inactive = to_mode_theme(),
}

require("lualine").setup({
  options = {
    icons_enabled = true,
    theme = theme,
    component_separators = "",
    section_separators = "",
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = vim.go.laststatus == 3,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    },
  },
  -- +-------------------------------------------------+
  -- | A | B | C                             X | Y | Z |
  -- +-------------------------------------------------+
  sections = {
    lualine_a = {
      -- { "mode", fmt = fmt_mode }
    },
    lualine_b = {
      -- { "branch", fmt = trunc(120, 12, 60) },
    },
    lualine_c = {
      -- "require('lsp-progress').progress()",
    },
    lualine_x = {
      workspace_name,
      relative_path,
    },
    lualine_y = {
      -- { -- git diff in numbers of lines
      --   "diff",
      --   colored = false,
      --   symbols = { added = "+", modified = "~", removed = "-" }, -- Changes the symbols used by the diff.
      -- },
      -- { -- Displays diagnostics for the defined severity types
      --   "diagnostics",
      --   sections = { "error", "warn" },
      --   diagnostics_color = { error = "GruvboxBg3", warn = "GruvboxBg3" },
      -- },
      "location",
      "progress",
    },
    lualine_z = {
      -- filetype,
    },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {},
    lualine_x = {
      workspace_name,
      relative_path,
    },
    lualine_y = { "location", "progress" },
    lualine_z = {},
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {},
})
