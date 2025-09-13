local Path = require("wax.path")

local find_relative_path = wax_cache_buf_fn(function(abspath)
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

local function relative_path()
  local abspath = vim.api.nvim_buf_get_name(0)
  if abspath == "" then
    return ""
  end
  return find_relative_path(abspath)
end

local function lsp_progress()
  return require("lsp-progress").progress({
    format = function(client_messages)
      if #client_messages > 0 then
        return table.concat(client_messages, " ")
      end
      return ""
    end,
  })
end

local function supermaven_status()
  local ok, api = pcall(require, "supermaven-nvim.api")
  if ok and api.is_running() then
    return "  "
  else
    return ""
  end
  -- if vim.g.SUPERMAVEN_DISABLED == 1 then
  --   return ""
  -- else
  --   return "  "
  -- end
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
      -- function()
      --   local ok, node = pcall(vim.treesitter.get_node)
      --   if ok then
      --     return node:type()
      --   end
      -- end,
    },
    lualine_x = {
      relative_path,
    },
    lualine_y = {
      supermaven_status,
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
    lualine_y = {
      supermaven_status,
      "location",
      "progress",
    },
    lualine_z = {},
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {},
})
