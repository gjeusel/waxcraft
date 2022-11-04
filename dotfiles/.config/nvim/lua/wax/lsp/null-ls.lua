local h = require("null-ls.helpers")
local u = require("null-ls.utils")
local s = require("null-ls.state")
local builtins = require("null-ls.builtins")
local methods = require("null-ls.methods")

local python_utils = require("wax.lsp.python-utils")

local function from_python_env(params)
  local resolved = s.get_cache(params.bufnr, params.command)
  if resolved then
    if resolved.command then
      log.debug(
        string.format(
          "Using cached value [%s] as the resolved command for [%s]",
          resolved.command,
          params.command
        )
      )
    end
    return resolved.command
  end

  local workspace = u.get_root()
  local cmd_for_env = python_utils.get_python_path(workspace, params.command)
  resolved = { command = cmd_for_env, cwd = workspace }

  s.set_cache(params.bufnr, params.command, resolved)
  return resolved.command
end

-- https://github.com/jose-elias-alvarez/null-ls.nvim/pull/1068
local ruff_custom_end_col = {
  end_col = function(entries, line)
    if not line then
      return
    end

    local start_col = entries["col"]
    local message = entries["message"]
    local code = entries["code"]
    local default_position = start_col + 1

    local pattern = nil
    local trimmed_line = line:sub(start_col, -1)

    if code == "F841" or code == "F823" then
      pattern = [[Local variable %`(.*)%`]]
    elseif code == "F821" or code == "F822" then
      pattern = [[Undefined name %`(.*)%`]]
    elseif code == "F401" then
      pattern = [[%`(.*)%` imported but unused]]
    elseif code == "F841" then
      pattern = [[Local variable %`(.*)%` is assigned to but never used]]
    elseif code == "R001" then
      pattern = [[Class %`(.*)%` inherits from object]]
    end
    if not pattern then
      return default_position
    end

    local results = message:match(pattern)
    local _, end_col = trimmed_line:find(results, 1, true)

    if not end_col then
      return default_position
    end

    end_col = end_col + start_col
    if end_col > tonumber(start_col) then
      return end_col
    end

    return default_position
  end,
}

local ruff = h.make_builtin({
  name = "ruff",
  meta = {
    url = "https://github.com/charliermarsh/ruff/",
    description = "An extremely fast Python linter, written in Rust.",
  },
  method = methods.internal.DIAGNOSTICS,
  filetypes = { "python" },
  generator_opts = {
    command = "ruff",
    args = {
      "--exit-zero",
      "--no-cache",
      "--stdin-filename",
      "$FILENAME",
      "-",
    },
    format = "line",
    check_exit_code = function(code)
      return code == 0
    end,
    to_stdin = true,
    ignore_stderr = true,
    on_output = h.diagnostics.from_pattern(
      [[(%d+):(%d+): ((%u)%w+) (.*)]],
      { "row", "col", "code", "severity", "message" },
      {
        adapters = { ruff_custom_end_col },
        severities = {
          E = h.diagnostics.severities["error"], -- pycodestyle errors
          W = h.diagnostics.severities["warning"], -- pycodestyle warnings
          F = h.diagnostics.severities["information"], -- pyflakes
          A = h.diagnostics.severities["information"], -- flake8-builtins
          B = h.diagnostics.severities["warning"], -- flake8-bugbear
          C = h.diagnostics.severities["warning"], -- flake8-comprehensions
          T = h.diagnostics.severities["information"], -- flake8-print
          U = h.diagnostics.severities["information"], -- pyupgrade
          D = h.diagnostics.severities["information"], -- pydocstyle
          M = h.diagnostics.severities["information"], -- Meta
        },
      }
    ),
  },
  factory = h.generator_factory,
})

local mypy_overrides = {
  severities = {
    error = h.diagnostics.severities["error"],
    warning = h.diagnostics.severities["warning"],
    note = h.diagnostics.severities["information"],
  },
}

-- local flake8_diagnostics = builtins.diagnostics.flake8.with({
--   method = methods.internal.DIAGNOSTICS_ON_SAVE,
--   command = "flake8",
--   dynamic_command = from_python_env,
-- })

local ruff_diagnostics = ruff.with({
  method = methods.internal.DIAGNOSTICS,
  command = "ruff",
  dynamic_command = from_python_env,
})

local sources = {
  -- builtins.completion.spell,

  -- python
  builtins.formatting.black.with({
    command = "black",
    dynamic_command = from_python_env,
    args = {
      "--fast",
      "--quiet",
      "--stdin-filename",
      "$FILENAME",
      "-",
    },
  }),
  builtins.formatting.isort.with({
    command = "isort",
    dynamic_command = from_python_env,
    args = {
      "--profile=black",
      "--stdout",
      "--filename",
      "$FILENAME",
      "-",
    },
  }),

  -- lua filetypes
  builtins.formatting.stylua,

  -- prisma filetypes
  -- builtins.formatting.prismaFmt,

  -- frontend
  -- builtins.formatting.rustywind, -- reorder tailwindcss classes
  -- builtins.diagnostics.tsc,
  -- builtins.formatting.prettierd,
  builtins.formatting.prettier.with({
    filetypes = {
      -- "javascript",
      -- "javascriptreact",
      -- "typescript",
      -- "typescriptreact",
      -- "vue",
      "css",
      "scss",
      "less",
      "html",
      -- done by json-ls
      "json",
      "jsonc",
      "yaml",
      "markdown",
      "graphql",
      "handlebars",
    },
  }),
  -- builtins.code_actions.eslint_d,
  builtins.diagnostics.eslint_d,
  builtins.formatting.eslint_d,
}

if vim.fn.executable("ruff") == 1 then
  table.insert(sources, ruff_diagnostics)
  -- elseif vim.fn.executable("flake8") == 1 then
  --   table.insert(sources, flake8_diagnostics)
end

require("null-ls").setup({
  debug = waxopts.loglevel == "debug",
  diagnostics_format = "(#{s}) #{c}: #{m}",
  root_dir = find_root_dir,
  update_in_insert = false,
  should_attach = function(bufnr)
    return not is_big_file(bufnr)
    -- return not vim.api.nvim_buf_get_name(bufnr):match("^diffview://")
  end,
  log = {
    enable = true,
    level = waxopts.loglevel,
    use_console = "async",
  },
  sources = sources,
})
