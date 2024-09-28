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
  local sober_theme = {
    a = "LualineA",
    b = "LualineB",
    c = "LualineC",
    x = "LualineX",
    y = "LualineY",
    z = "LualineZ",
  }

  return {
    normal = sober_theme,
    insert = sober_theme,
    visual = sober_theme,
    replace = sober_theme,
    command = sober_theme,
    inactive = sober_theme,
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
