local fzf_lua = require("fzf-lua")

local Path = require("wax.path")

local rg_ignore_dirs = {
  ".git",
  "**/*orig", -- merge conflicts
  ".jj",
  --
  "**/postgres-data", -- docker volume
  "**/edgedb-data", -- docker volume
  "**/.vscode", -- vscode ? Nop
  "**/playground/*", -- messy
  --
  "data.ms", -- meilisearch
  "**/clients-cache", -- hishel httpx cache in venturi
  --
  "history/*", -- dagster
  "storage/**/compute_logs", -- dagster
  --
  "**/*.pyc",
  "**/__pycache__",
  "**/.venv",
  ".eggs",
  "**/.ropeproject",
  -- "**/__snapshots__",
  -- "**/tests/data",
  "**/.*_cache",
  --
  "**/.dist/*",
  "**/dist/*",
  "**/.nuxt/*",
  "**/.output/*",
  "**/node_modules/*",
  "**/.vercel/output/*",
  --
  "**/coverage/*", -- test coverage reports
  "**/.next/*", -- Next.js build output
  "**/.turbo/*", -- Turborepo cache
  "**/target/*", -- Rust/Maven target
  "**/.cargo/*", -- Rust cargo cache
  "**/vendor/*", -- Go/PHP vendor
}

local rg_ignore_files = {
  "*.min.css",
  "*.min.js", -- minified JS
  "*.chunk.js", -- webpack chunks
  "*.bundle.js", -- bundles
  "*.svg",
  "*.pdf",
  "pnpm-lock.yaml",
  "package-lock.json",
  "edgedb.toml",
}

local rg_ignore_arg = ("--glob '!{%s}' --glob '!{%s}'"):format(
  table.concat(rg_ignore_dirs, ","),
  table.concat(rg_ignore_files, ",")
)

-- Reusable rg option groups
local rg_base_opts = "--hidden"
local rg_perf_opts = "--max-filesize=2M"

-- Full command bases
local rg_grep_cmd = ("rg --line-number --column --no-ignore-vcs %s %s %s"):format(
  rg_base_opts,
  rg_perf_opts,
  rg_ignore_arg
)
local rg_files_cmd = ("rg --no-ignore-vcs --files %s %s"):format(rg_base_opts, rg_ignore_arg)

-- Wrapper: builtin file_edit_or_qf + jump to first qf entry + add files to buffers
local function file_edit_or_qf_cfirst(selected, opts)
  if #selected <= 2 then -- single select (first element is keybind)
    fzf_lua.actions.file_edit_or_qf(selected, opts)
    return
  end

  -- Multi-select: parse entries and populate quickfix
  local items = {}
  for i = 1, #selected do
    local entry = selected[i]
    local file = fzf_lua.path.entry_to_file(entry, opts)
    local text = entry:match(":%d+:%d?%d?%d?%d?:?(.*)$") or ""
    table.insert(items, {
      filename = file.bufname or file.path,
      lnum = file.line or 1,
      col = file.col or 1,
      text = text,
    })
  end

  -- Load all files into buffers first
  for _, item in ipairs(items) do
    vim.fn.bufadd(item.filename)
  end

  vim.fn.setqflist({}, "r", { title = "FZF Selection", items = items })
  vim.cmd("copen")
  vim.cmd("cfirst")
end

local fzf_actions = {
  ["default"] = file_edit_or_qf_cfirst,
  ["ctrl-s"] = fzf_lua.actions.file_split,
  ["ctrl-v"] = fzf_lua.actions.file_vsplit,
}

-- fzf keybinds for fzf_exec (doesn't inherit from setup)
local fzf_exec_opts = {
  ["--multi"] = "", -- enable multi-select
  ["--bind"] = "ctrl-r:select-all+accept",
}

fzf_lua.setup({
  winopts = {
    height = 0.8,
    width = 0.9,
    treesitter = { enabled = false },
    preview = {
      flip_columns = 200, -- number of cols to switch to horizontal on flex
      wrap = "wrap",
    },
  },
  fzf_opts = {
    ["--cycle"] = "", -- enable cycling
  },
  actions = { files = fzf_actions },
  keymap = {
    builtin = {
      ["<c-d>"] = "preview-page-down",
      ["<c-u>"] = "preview-page-up",
    },
    fzf = {
      ["ctrl-d"] = "preview-page-down",
      ["ctrl-u"] = "preview-page-up",
      ["ctrl-r"] = "select-all+accept", -- https://github.com/ibhagwan/fzf-lua/issues/324
    },
  },
  grep = {
    fzf_opts = {
      -- ["--bind"] = "", -- disable all binds
    },
    actions = fzf_actions,
    prompt = "❯ ",
    git_icons = false,
    file_icons = false,
    multiprocess = true,
    rg_glob = true, -- enable inline glob filtering: `pattern -- *.lua !*test*`
    -- debug = true,
    cwd_header = false,
    rg_opts = table.concat({
      rg_base_opts,
      "--column",
      "--line-number",
      "--no-heading",
      "--color=always",
      "--smart-case",
      "--max-columns=512",
      "--max-columns-preview",
      rg_perf_opts,
      rg_ignore_arg,
    }, " "),
  },
})

-- -- Register fzf-lua for vim.ui.select
fzf_lua.register_ui_select({ winopts = { height = 0.33, width = 0.33 } }, true)
-- fzf_lua.deregister_ui_select({}, true)

--
---------- Grep ----------
--
-- Fzf Grep
local function fzf_grep(cwd)
  return fzf_lua.grep({
    winopts = { title = ("  %s  "):format(cwd), title_flags = false },
    cmd = rg_grep_cmd,
    cwd = cwd,
    search = "",
  })
end

-- Fzf Grep word under cursor
local function grep_cword(cwd)
  vim.cmd([[normal! "wyiw]])
  local word = vim.fn.getreg('"')

  return fzf_lua.grep_cword({
    winopts = { title = ("  %s   -   %s  "):format(word, cwd), title_flags = false },
    cmd = rg_grep_cmd,
    cwd = cwd,
  })
end

--
---------- Files ----------
--
local function rg_files(cwd)
  return fzf_lua.fzf_exec(rg_files_cmd, {
    winopts = { title = ("  %s  "):format(cwd) },
    fzf_opts = fzf_exec_opts,
    previewer = "builtin",
    cwd = cwd,
    actions = fzf_actions,
  })
end

--
---------- LSP ----------
--
-- lsp issue with tips and tricks: https://github.com/ibhagwan/fzf-lua/issues/441
--
local function lsp_references()
  fzf_lua.lsp_references({
    file_ignore_patterns = { "miniconda3", "node_modules" }, -- ignore references in env libs
  })
end

--
------- Wax files -------

local function wax_files()
  local paths = {
    ".zshrc",
    "src/waxcraft/nvim",
    "src/waxcraft/dotfiles",
    "src/waxcraft/colorschemes",
    "src/waxcraft/nix",
    "src/waxcraft/zsh",
    ".local/share/nvim/lazy",
  }
  local home = vim.env.HOME
  local abs_paths = vim.tbl_map(function(path)
    return home .. "/" .. path
  end, paths)

  local cmd = ("rg %s %s --files %s"):format(
    rg_base_opts,
    rg_ignore_arg,
    table.concat(abs_paths, " ")
  )

  return fzf_lua.fzf_exec(cmd, {
    prompt = "WaxFiles > ",
    fzf_opts = fzf_exec_opts,
    previewer = "builtin",
    cwd = vim.env.HOME,
    actions = fzf_actions,
  })
end

--
------- Project Select first -------

local function pick_project(fn)
  local src_path = Path.home():join("src")

  local projects = vim.tbl_filter(function(path)
    return path:is_directory()
  end, src_path:ls())

  projects = vim.tbl_map(function(path)
    return (path:make_relative(src_path)).path
  end, projects)

  vim.ui.select(projects, { prompt = "Select project> " }, function(choice, _)
    if choice then
      vim.schedule(function()
        fn(src_path:join(choice):absolute())
      end)
    end
  end)
end

local function select_project_find_file()
  return pick_project(function(path)
    rg_files(path)
  end)
end

local function select_project_fzf_grep()
  return pick_project(function(path)
    fzf_grep(path)
  end)
end

return {
  -- grep
  fzf_grep = fzf_grep,
  grep_cword = grep_cword,
  -- files
  rg_files = rg_files,
  -- lsp
  lsp_references = lsp_references,
  -- custom
  wax_files = wax_files,
  select_project_find_file = select_project_find_file,
  select_project_fzf_grep = select_project_fzf_grep,
}
