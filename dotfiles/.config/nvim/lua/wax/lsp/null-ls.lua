local u = require("null-ls.utils")
local s = require("null-ls.state")
local builtins = require("null-ls.builtins")
-- local methods = require("null-ls.methods")

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
  -- builtins.formatting.isort.with({
  --   command = "isort",
  --   dynamic_command = from_python_env,
  --   args = {
  --     "--profile=black",
  --     "--stdout",
  --     "--filename",
  --     "$FILENAME",
  --     "-",
  --   },
  -- }),

  -- builtins.diagnostics.ruff.with({
  --   method = methods.internal.FORMATTING,
  --   command = "ruff",
  --   args = {
  --     "--exit-zero",
  --     "--no-cache",
  --     "--fix",
  --     "--stdin-filename",
  --     "$FILENAME",
  --     "-",
  --   },
  --   dynamic_command = from_python_env,
  -- }),
  -- builtins.diagnostics.ruff.with({
  --   method = methods.internal.DIAGNOSTICS,
  --   command = "ruff",
  --   dynamic_command = from_python_env,
  -- }),

  -- lua filetypes
  builtins.formatting.stylua,

  -- prisma filetypes
  -- builtins.formatting.prismaFmt,

  -- rust filetypes
  -- builtins.formatting.rustfmt,

  -- frontend
  builtins.formatting.djhtml.with({
    filetypes = { "django", "jinja.html", "htmldjango" },
    command = "djhtml",
    args = { "--tabwidth", "2" },
    dynamic_command = from_python_env,
  }),
  -- builtins.formatting.rustywind, -- reorder tailwindcss classes
  -- builtins.diagnostics.tsc,
  -- builtins.formatting.prettier.with({
  --   method = methods.internal.RANGE_FORMATTING,
  --   filetypes = {
  --     "typescriptreact",
  --   },
  -- }),
  builtins.formatting.prettier.with({
    filetypes = {
      -- "javascript",
      -- "javascriptreact",
      -- "typescript",
      -- "typescriptreact",
      -- "vue",  -- prettier with only range is used for vue files.
      "css",
      "scss",
      "less",
      -- "html",
      -- done by json-ls
      -- "json",
      -- "jsonc",
      "yaml",
      "markdown",
      "graphql",
      "handlebars",
    },
  }),
  -- builtins.code_actions.eslint_d,
  builtins.diagnostics.eslint_d,
  builtins.formatting.eslint_d,
  -- builtins.diagnostics.eslint,
  -- builtins.formatting.eslint,
}

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
