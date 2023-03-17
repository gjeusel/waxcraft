local function fn_cache(fn)
  local cache = {}

  local function cached_fn()
    local abspath = vim.api.nvim_buf_get_name(0)
    if vim.tbl_contains(vim.tbl_keys(cache), abspath) then
      return cache[abspath]
    end
    local result = fn()
    cache[abspath] = result
  end

  return cached_fn
end

local workspace_name = fn_cache(function()
  return find_workspace_name() or ""
end)

local relative_path = fn_cache(function()
  local abspath = vim.api.nvim_buf_get_name(0)
  local workspace = find_root_dir(abspath)
  local Path = require("plenary.path")

  if workspace then
    return Path:new(abspath):make_relative(workspace)
  else
    return Path:new(abspath):make_relative(vim.env.HOME)
  end
end)

local function diagnostics()
  if #vim.lsp.buf_get_clients() > 0 then
    return require("lsp-status").status()
  else
    return ""
  end
end

local function filetype()
  return vim.api.nvim_buf_get_option(0, "filetype")
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
  -- a = { bg = colors.GruvboxBg1, fg = colors.green },
  -- b = { bg = colors.GruvboxBg0, fg = colors.GruvboxBg3 },
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
    -- component_separators = { left = "·", right = "·" },
    -- section_separators = { left = "", right = "" },
    -- component_separators = { left = "", right = "" },
    -- section_separators = { left = "", right = "" },
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
    lualine_a = { { "mode", fmt = fmt_mode } },
    lualine_b = { workspace_name, { "branch", fmt = trunc(120, 12, 60) } },
    lualine_c = { "spell", "readonly", "modified", diagnostics },
    lualine_x = { relative_path },
    lualine_y = { "location", "progress" },
    lualine_z = { filetype },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { relative_path },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {},
})
