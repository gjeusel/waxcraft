local python_utils = require("wax.lsp.python-utils")

local function to_python_cmd(cmd)
  local function inner()
    return {
      command = python_utils.get_python_path(nil, cmd),
    }
  end
  return inner
end

require("conform").setup({
  formatters = {
    ruff_fix = to_python_cmd("ruff"),
    ruff_format = to_python_cmd("ruff"),
    isort = to_python_cmd("isort"),
    black = to_python_cmd("black"),
    djhtml = to_python_cmd("djhtml"),
  },
  --
  formatters_by_ft = {
    lua = { "stylua" },
    python = function(bufnr)
      if require("conform").get_formatter_info("ruff_format", bufnr).available then
        return { "ruff_fix", "ruff_format" }
      else
        return { "isort", "black" }
      end
    end,
    ["jinja.html"] = { "djhtml" },
    javascript = { { "prettierd", "prettier" }, { "eslint_d", "eslint" } },
    typescript = { { "prettierd", "prettier" }, { "eslint_d", "eslint" } },
    vue = { { "prettierd", "prettier" }, { "eslint_d", "eslint" } },
  },
})
