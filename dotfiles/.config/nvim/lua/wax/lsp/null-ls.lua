local u = require("null-ls.utils")
local s = require("null-ls.state")
local builtins = require("null-ls.builtins")
local cmd_resolver = require("null-ls.helpers.command_resolver")

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

local eslint_filetypes = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "vue",
  "svelte",
}
local eslint_cfg = {
  filetypes = eslint_filetypes,
  dynamic_command = cmd_resolver.from_node_modules(),
}

local prettier_filetypes = eslint_filetypes
local prettier_cfg = {
  filetypes = prettier_filetypes,
  dynamic_command = cmd_resolver.from_node_modules(),
}

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

  -- builtins.formatting.prettier.with(prettier_cfg),
  builtins.formatting.prettierd.with(prettier_cfg),

  -- builtins.code_actions.eslint_d,
  builtins.diagnostics.eslint_d.with(eslint_cfg),
  builtins.formatting.eslint_d.with(eslint_cfg),
  -- builtins.diagnostics.eslint.with(eslint_cfg),
  -- builtins.formatting.eslint.with(eslint_cfg),

  -- sql
  -- builtins.formatting.sql_formatter,
  -- builtins.diagnostics.sqlfluff.with({ extra_args = { "--dialect", "postgres" } }),
  -- builtins.formatting.sqlfluff.with({ extra_args = { "--dialect", "postgres" } }),
}

require("null-ls").setup({
  debug = waxopts.loglevel == "debug",
  diagnostics_format = "(#{s}) #{c}: #{m}",
  root_dir = find_root_dir,
  update_in_insert = false,
  should_attach = function(bufnr)
    local fpath = vim.api.nvim_buf_get_name(bufnr)
    return not is_big_file(fpath)
    -- return not vim.api.nvim_buf_get_name(bufnr):match("^diffview://")
  end,
  log = {
    enable = true,
    level = waxopts.loglevel,
    use_console = "async",
  },
  sources = sources,
})
