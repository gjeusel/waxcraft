---@class Wax.LspServerOpts
---@field name string
---@field blacklist table<string>

---@class Wax.Opts
---@field loglevel "trace" | "debug" | "info" | "warn" | "error"
---@field python3 string
---@field colorscheme string
---@field big_file_threshold number
---@field servers table<string, Wax.LspServerOpts>
---@field _servers table<string, any> | nil

---@type Wax.Opts
waxopts = {
  loglevel = "info",
  python3 = "python",
  colorscheme = os.getenv("ITERM_PROFILE") or "gruvbox",
  big_file_threshold = 1024 * 1024 * 0.5, -- 0.5 Megabyte
  servers = {
    -- tsserver = { blacklist = { "some-project" } },
  },
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

-- Python config
vim.g.python3_host_prog = waxopts.python3

-- -- enable debug (neovim logfile is in $NVIM_LOG_FILE)
-- if waxopts.loglevel == "debug" then
--   vim.o.debug = "msg"
--   vim.o.verbosefile = vim.fn.stdpath("cache") .. "/nvim-verbosefile.log"
--   vim.o.verbose = 1 -- 16 is max
-- end
