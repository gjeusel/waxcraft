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
      log:debug(
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
      "-n",
      "$FILENAME",
    },
    format = "line",
    check_exit_code = function(code)
      return code == 0
    end,
    to_stdin = false,
    from_stderr = true,
    to_temp_file = true,
    on_output = h.diagnostics.from_pattern(
      [[(%d+):(%d+): ((%u)%w+) (.*)]],
      { "row", "col", "code", "severity", "message" },
      {
        adapters = { ruff_custom_end_col },
        severities = {
          E = h.diagnostics.severities["error"],
          F = h.diagnostics.severities["warning"],
          R = h.diagnostics.severities["error"],
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

require("null-ls").setup({
  debug = waxopts.loglevel == "debug",
  diagnostics_format = "(#{s}) #{c}: #{m}",
  log = {
    enable = true,
    level = waxopts.loglevel,
    use_console = "async",
  },
  sources = {
    -- builtins.completion.spell,

    -- python
    -- builtins.diagnostics.flake8.with({
    --   method = methods.internal.DIAGNOSTICS_ON_SAVE,
    --   command = "flake8",
    --   dynamic_command = from_python_env,
    -- }),
    ruff.with({
      method = methods.internal.DIAGNOSTICS,
      command = "ruff",
      dynamic_command = from_python_env,
    }),
    -- builtins.diagnostics.mypy.with({
    --   method = methods.internal.DIAGNOSTICS_ON_SAVE,
    --   command = "mypy",
    --   dynamic_command = from_python_env,
    --   args = function(params)
    --     return {
    --       "--sqlite-cache",
    --       "--cache-fine-grained",
    --       --
    --       "--no-color-output",
    --       "--show-column-numbers",
    --       "--show-error-codes",
    --       "--hide-error-context",
    --       "--no-error-summary",
    --       "--show-absolute-path",
    --       "--no-pretty",
    --       -- "--shadow-file",
    --       -- params.bufname,
    --       -- params.temp_path,
    --       params.bufname,
    --     }
    --   end,
    --   on_output = h.diagnostics.from_patterns({
    --     { -- case with column given
    --       pattern = "([^:]+):(%d+):(%d+): (%a+): (.*)  %[([%a-]+)%]",
    --       groups = { "filename", "row", "col", "severity", "message", "code" },
    --       overrides = mypy_overrides,
    --     },
    --     { -- case with missing column
    --       pattern = "([^:]+):(%d+): (%a+): (.*)  %[([%a-]+)%]",
    --       groups = { "filename", "row", "severity", "message", "code" },
    --       overrides = mypy_overrides,
    --     },
    --   }),
    --   timeout = 1 * 60 * 1000, -- 5 min
    -- }),
    builtins.formatting.black.with({
      command = "black",
      dynamic_command = from_python_env,
      args = {
        "--fast",
        "--quiet",
        -- only available since black 21.5b0
        -- https://github.com/jose-elias-alvarez/null-ls.nvim/commit/a31cafefaf25a0125d063f2a1ee315953c00d796
        -- "--stdin-filename",
        -- "$FILENAME",
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
  },
})
