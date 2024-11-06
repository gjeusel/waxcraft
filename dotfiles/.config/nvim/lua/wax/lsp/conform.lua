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
        "E203,F841,F401,RUF100,B007",
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
    djhtml = to_python_cmd("djhtml"),
  },
  --
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "ruff_organize_imports", "ruff_fix", "ruff_format" },
    -- python = { "isort", "black" },
    ["jinja.html"] = { "djhtml" },
    javascript = frontend_cfg,
    typescript = frontend_cfg,
    typescriptreact = frontend_cfg,
    vue = frontend_cfg,
    yaml = { "prettier" },
    markdown = { "prettier" },
    css = { "prettier" },
    xml = { "xmlformat" },
    rust = { "rustfmt" },
    toml = { "taplo" },
    jsonc = { "jq" },
    sql = { "sqlfmt" },
  },
})
