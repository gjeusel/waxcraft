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

local lsp_progress = function()
  return require("lsp-progress").progress({
    format = function(client_messages)
      if #client_messages > 0 then
        return table.concat(client_messages, " ")
      end
      return ""
    end,
  })
end

local function make_theme()
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

  return {
    normal = to_mode_theme(),
    insert = to_mode_theme(),
    visual = to_mode_theme(),
    replace = to_mode_theme(),
    command = to_mode_theme(),
    inactive = to_mode_theme(),
  }
end

require("lualine").setup({
  options = {
    icons_enabled = true,
    theme = make_theme(),
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
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      lsp_progress,
      function()
        return require("dap").status()
      end,
    },
    lualine_x = {
      relative_path,
    },
    lualine_y = {
      "location",
      "progress",
    },
    lualine_z = {},
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {},
    lualine_x = {
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
