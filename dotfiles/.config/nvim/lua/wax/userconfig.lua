-------- waxopts handle --------

---@class Wax.LspServerOpts
---@field name string
---@field blacklist table<string>
---@field whitelist table<string>

---@class Wax.Opts
---@field loglevel "trace" | "debug" | "info" | "warn" | "error"
---@field python3 string
---@field colorscheme string
---@field big_file_threshold number
---@field servers table<Wax.LspServerOpts | string>
---@field _servers table<string, Wax.LspServerOpts>

---@type Wax.Opts
waxopts = {
  loglevel = "info",
  python3 = "python3",
  colorscheme = os.getenv("ITERM_PROFILE") or "gruvbox",
  big_file_threshold = 1024 * 1024, -- 1 Megabyte
  servers = {
    -- -- ________ generic ________
    -- "lua_ls",
    -- "bashls",
    -- "yamlls",
    -- "jsonls",
    -- "vimls",
    -- "taplo", -- toml
    -- --
    -- -- ________ frontend ________
    -- "tsserver",
    -- "html",
    -- "svelte",
    -- "volar",
    -- "cssls",
    -- "tailwindcss",
    -- --
    -- -- ________ backend ________
    -- "pylsp",
    -- "ruff_lsp",
    -- "pyright",
    -- "rust_analyzer",
    -- "clangd",
    -- "prismals",
    -- -- ________ mobile ________
    -- "dartls",
    -- -- ________ infra ________
    -- "terraformls",
    -- "dockerls",
  },
  _servers = {},
}

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

load_local_config(vim.env.HOME .. "/.config/nvim/config.lua")

------- coerce config fields -------

local function _to_lsp_server_opts(opts)
  local base_tbl = { whitelist = {}, blacklist = {} }
  if type(opts) == "string" then
    return vim.tbl_extend("keep", { name = opts }, base_tbl)
  else
    return vim.tbl_extend("keep", opts, base_tbl)
  end
end

for _, server_opts in pairs(waxopts.servers) do
  local opts = _to_lsp_server_opts(server_opts)
  waxopts._servers[opts.name] = opts
end
