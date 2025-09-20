---@class Wax.Opts
---@field loglevel "trace" | "debug" | "info" | "warn" | "error"
---@field python3 string
---@field big_file_threshold number

---@type Wax.Opts
waxopts = {
  loglevel = "warn",
  python3 = "python",
  big_file_threshold = 1024 * 1024 * 0.5, -- 0.5 Megabyte
}

-- Python config
vim.g.python3_host_prog = waxopts.python3

-- -- enable debug (neovim logfile is in $NVIM_LOG_FILE)
-- if waxopts.loglevel == "debug" then
--   vim.o.debug = "msg"
--   vim.o.verbosefile = vim.fn.stdpath("cache") .. "/nvim-verbosefile.log"
--   vim.o.verbose = 1 -- 16 is max
-- end
