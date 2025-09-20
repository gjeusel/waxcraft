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

local function get_class_function_loc()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    return ""
  end

  local class_name = nil
  local function_name = nil

  -- Walk up the tree to find class and function nodes
  local current = node
  while current do
    local node_type = current:type()

    -- Look for function/method nodes
    if
      not function_name
      and (
        node_type == "function_declaration"
        or node_type == "function_definition"
        or node_type == "method_definition"
        or node_type == "function_item"
        or node_type == "method_declaration"
        or node_type == "arrow_function"
        or node_type == "function_expression"
        or node_type == "function"
      )
    then
      -- Try to get the function name from various possible child nodes
      for child in current:iter_children() do
        local child_type = child:type()
        if
          child_type == "identifier"
          or child_type == "name"
          or child_type == "property_identifier"
        then
          function_name = vim.treesitter.get_node_text(child, 0)
          break
        end
      end
    end

    -- Look for class nodes
    if
      not class_name
      and (
        node_type == "class_declaration"
        or node_type == "class_definition"
        or node_type == "class"
        or node_type == "impl_item"
        or node_type == "struct_item"
        or node_type == "interface_declaration"
      )
    then
      -- Try to get the class name from various possible child nodes
      for child in current:iter_children() do
        local child_type = child:type()
        if
          child_type == "identifier"
          or child_type == "name"
          or child_type == "type_identifier"
        then
          class_name = vim.treesitter.get_node_text(child, 0)
          break
        end
      end
    end

    -- Move to parent node
    current = current:parent()
  end

  -- Format the result
  if class_name and function_name then
    return class_name .. "::" .. function_name
  elseif function_name then
    return function_name
  elseif class_name then
    return class_name
  else
    return ""
  end
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
      get_class_function_loc,
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
