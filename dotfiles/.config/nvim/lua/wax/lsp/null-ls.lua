local h = require("null-ls.helpers")
local u = require("null-ls.utils")
local s = require("null-ls.state")
local builtins = require("null-ls.builtins")
local methods = require("null-ls.methods")

local python_utils = require("wax.lsp.python-utils")

local function from_python_env(params)
  local resolved = s.get_resolved_command(params.bufnr, params.command)
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

  s.set_resolved_command(params.bufnr, params.command, resolved)
  return resolved.command
end

require("null-ls").setup({
  -- debug = true,
  log = {
    enable = true,
    level = waxopts.loglevel,
    use_console = "async",
  },
  sources = {
    -- builtins.completion.spell,

    -- python
    builtins.diagnostics.flake8.with({
      -- method = methods.internal.DIAGNOSTICS_ON_SAVE,
      command = "flake8",
      dynamic_command = from_python_env,
    }),
    builtins.diagnostics.mypy.with({
      method = methods.internal.DIAGNOSTICS_ON_SAVE,
      command = "mypy",
      dynamic_command = from_python_env,
      args = function(params)
        return {
          -- "--sqlite-cache",
          -- "--cache-fine-grained",
          --
          "--no-color-output",
          "--show-column-numbers",
          "--show-error-codes",
          "--hide-error-context",
          "--no-error-summary",
          "--show-absolute-path",
          "--no-pretty",
          "--shadow-file",
          params.bufname,
          params.temp_path,
          params.bufname,
        }
      end,
      on_output = h.diagnostics.from_patterns({
        { -- case with column given
          pattern = "([^:]+):(%d+):(%d+): (%a+): (.*)  %[([%a-]+)%]",
          groups = { "filename", "row", "col", "severity", "message", "code" },
          overrides = {
            severities = {
              error = h.diagnostics.severities["error"],
              warning = h.diagnostics.severities["warning"],
              note = h.diagnostics.severities["information"],
            },
          },
        },
        { -- case with missing column
          pattern = "([^:]+):(%d+): (%a+): (.*)  %[([%a-]+)%]",
          groups = { "filename", "row", "severity", "message", "code" },
          overrides = {
            severities = {
              error = h.diagnostics.severities["error"],
              warning = h.diagnostics.severities["warning"],
              note = h.diagnostics.severities["information"],
            },
          },
        },
      }),
      timeout = 1 * 60 * 1000, -- 5 min
    }),
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
    builtins.formatting.prismaFmt,

    -- frontend
    -- builtins.formatting.rustywind, -- reorder tailwindcss classes
    -- builtins.diagnostics.tsc,
    builtins.formatting.prettierd,
    -- builtins.formatting.prettier,
    -- builtins.code_actions.eslint_d,
    -- builtins.formatting.eslint,
  },
})
