-- ________ waxopts handle ________

waxopts = {
  loglevel = "info",
  python3 = "python3",
  lsp = {
    loglevel = "warn",
    lspinstall = { loglevel = "warn" },
    servers = {},
    -- servers = {
    --   -- ________ generic ________
    --   "efm",
    --   "sumneko_lua",
    --   "bashls",
    --   "yamlls",
    --   "jsonls",
    --   "vimls",
    --   -- ________ frontend ________
    --   "tsserver",
    --   "html",
    --   -- "svelte",
    --   -- "vuels",
    --   "volar",
    --   "cssls",
    --   "tailwindcss",
    --   -- ________ backend ________
    --   "pylsp",
    -- { name = "pyright", on_projects = { "projectname" } },
    --   -- ________ infra ________
    --   "terraformls",
    --   "dockerls",
    -- },
  },
}

local function _to_lsp_server_opts(opts)
  if type(opts) == "string" then
    return { name = opts, on_projects = nil }
  else
    return opts
  end
end

local function load_local_config(config_path)
  if vim.fn.filereadable(config_path) == 0 then
    return
  end

  local ok, err = pcall(vim.cmd, "luafile " .. config_path)
  if not ok then
    print("Invalid configuration", config_path)
    print(err)
    return
  end
end

local function sanitize_config()
  -- Ensure type of waxopts.lsp._servers being { [name] = {name = string, on_projects = nil | array } }
  waxopts.lsp._servers = {}
  for _, server_opts in pairs(waxopts.lsp.servers) do
    local opts = _to_lsp_server_opts(server_opts)
    waxopts.lsp._servers[opts.name] = opts
  end
end

load_local_config(vim.env.HOME .. "/.config/nvim/config.lua")

sanitize_config()


-- ________ global utilities ________

require("wax.utils.os")
require("wax.utils.remaps")

if is_module_available("plenary.log") then
  log = require("plenary.log").new({
    plugin = "wax",
    level = waxopts.loglevel,
    use_console = false,
  })
else
  local mockfn = function(_) end
  log = setmetatable({}, { __index = mockfn })
end
