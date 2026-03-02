local python_utils = require("wax.lsp.python-utils")

local function to_python_cmd(cmd, tbl)
  local function inner()
    local command = python_utils.get_python_path(nil, cmd)
    return vim.tbl_extend("force", tbl or {}, { command = command })
  end
  return inner
end

local frontend_cfg = { "prettierd", "eslint_d" }
-- local frontend_cfg = { "prettier", "eslint" }

local function has_oxfmt(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local root = find_root_package(bufname)
  if not root then return false end
  return vim.fn.filereadable(root .. "/.oxfmtrc.json") == 1
end

local function has_oxlint(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local root = find_root_package(bufname)
  if not root then return false end
  return vim.fn.filereadable(root .. "/.oxlintrc.json") == 1
end

local function oxc_or(bufnr, fallback)
  local fmts = {}
  if has_oxfmt(bufnr) then table.insert(fmts, "oxfmt") end
  if has_oxlint(bufnr) then table.insert(fmts, "oxlint_fix") end
  if #fmts > 0 then return fmts end
  return fallback
end

require("conform").setup({
  formatters = {
    ruff_fix = to_python_cmd("ruff", {
      args = {
        "check",
        "--fix",
        "--force-exclude",
        "--exit-zero",
        "--no-cache",
        "--ignore",
        "E203,F841,F401,RUF100,B007,PERF102",
        "--stdin-filename",
        "$FILENAME",
        "-",
      },
    }),
    ruff_format = to_python_cmd(
      "ruff",
      { args = { "format", "--force-exclude", "--stdin-filename", "$FILENAME", "-" } }
    ),
    ruff_organize_imports = to_python_cmd("ruff", {
      args = {
        "check",
        "--fix",
        "--force-exclude",
        "--select=I001",
        "--exit-zero",
        "--no-cache",
        "--stdin-filename",
        "$FILENAME",
        "-",
      },
    }),
    --
    isort = to_python_cmd("isort"),
    black = to_python_cmd("black"),
    djhtml = to_python_cmd("djhtml", { args = { "--tabwidth", "2" } }),
    oxfmt = {
      command = "oxfmt",
      args = { "--stdin-filepath", "$FILENAME" },
      stdin = true,
    },
    oxlint_fix = {
      command = "oxlint",
      args = { "--fix", "$FILENAME" },
      stdin = false,
    },
  },
  --
  formatters_by_ft = {
    nix = { "alejandra" },
    lua = { "stylua" },
    just = { "just" },
    python = { "ruff_organize_imports", "ruff_fix", "ruff_format" },
    ["jinja.html"] = { "djhtml" },
    ["jinja"] = { "djhtml" },
    --
    javascript = function(bufnr) return oxc_or(bufnr, frontend_cfg) end,
    typescript = function(bufnr) return oxc_or(bufnr, frontend_cfg) end,
    typescriptreact = function(bufnr) return oxc_or(bufnr, frontend_cfg) end,
    vue = function(bufnr) return oxc_or(bufnr, frontend_cfg) end,
    --
    css = { "oxfmt" },
    yaml = { "oxfmt" },
    markdown = { "oxfmt" },
    jsonc = { "oxfmt" },
    --
    xml = { "xmlformat" },
    rust = { "rustfmt" },
    toml = { "taplo" },
    sql = { "sqlfmt" }, -- sqruff / pg_format
  },
})
