local fzf_lua = require("fzf-lua")

local Path = require("wax.path")

local rg_ignore_dirs =
  { ".git", ".*_cache", "postgres-data", "edgedb-data", "__pycache__", ".vscode" }
local rg_ignore_files = { "*.min.css", "*.svg", "pnpm-lock.yaml", "package-lock.json", "edgedb.toml"}
local rg_ignore_arg = ("--glob '!{%s}' --glob '!{%s}'"):format(
  table.concat(rg_ignore_dirs, ","),
  table.concat(rg_ignore_files, ",")
)

local fzf_actions = {
  ["default"] = fzf_lua.actions.file_edit,
  ["ctrl-s"] = fzf_lua.actions.file_split,
  ["ctrl-v"] = fzf_lua.actions.file_vsplit,
  -- ["ctrl-r"] = fzf_lua.actions.file_sel_to_qf,  -- not working in multiselect
}

fzf_lua.setup({
  winopts = {
    height = 0.8,
    width = 0.9,
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
    debug = true,
    show_cwd_header = false,
    rg_opts = table.concat({
      "--hidden --column --line-number --no-heading --color=always --smart-case",
      rg_ignore_arg,
    }, " "),
  },
})

-- -- Register fzf-lua for vim.ui.select
-- fzf_lua.register_ui_select({ winopts = { height = 0.33, width = 0.33 } }, true)
-- fzf_lua.deregister_ui_select({}, true)

--
------- utils funcs -------
--

local function git_or_cwd()
  local cwd = vim.fn.getcwd()
  if is_git() then
    cwd = find_root_dir(cwd, { ".git" })
  end
  return cwd
end

---@class FzfFileEntry
---@field filename string
---@field lnum number
---@field col number
---@field text string

---@param entries table<string>
---@param opts table<any>
---@return table<FzfFileEntry>
local function parse_entries(entries, opts)
  return vim.tbl_map(function(entry)
    local file = fzf_lua.path.entry_to_file(entry, opts)
    local text = entry:match(":%d+:%d?%d?%d?%d?:?(.*)$")
    return {
      filename = file.bufname or file.path,
      lnum = file.line,
      col = file.col,
      text = text,
    }
  end, entries)
end

local function fn_selected_multi(selected, opts)
  if not selected then
    return
  end

  -- first element of "selected" is the keybind pressed
  if #selected <= 2 then
    fzf_lua.actions.act(opts.actions, selected, opts)
  else -- here we multi-selected ("select-all+accept" on fzf lua view point)
    local _, entries = fzf_lua.actions.normalize_selected(opts.actions, selected)
    entries = parse_entries(entries, opts)

    local multiselect_actions = {
      "Open occurrences in qf list",
      "Open unique files in qf list",
    }

    vim.ui.select(
      multiselect_actions,
      { prompt = "FZF Actions (multi select)> " },
      function(choice, idx)
        vim.cmd("stopinsert")

        log.debug("fzf multi select: ", choice)

        if idx == 2 then
          local seen = {}
          entries = vim.tbl_filter(function(entry)
            if vim.tbl_contains(seen, entry.filename) then
              return false
            else
              table.insert(seen, entry.filename)
              return true
            end
          end, entries)
        end

        vim.fn.setqflist(entries, "r")
        vim.cmd("cfirst")
      end
    )
  end
end

--
---------- Grep ----------
--
-- Fzf Grep
local function fzf_grep()
  return fzf_lua.grep({
    cwd = git_or_cwd(),
    search = "",
    fn_selected = fn_selected_multi,
  })
end

-- Live Grep
local function live_grep()
  fzf_lua.live_grep({ cwd = git_or_cwd(), fn_selected = fn_selected_multi })
end

-- Fzf Grep word under cursor
local function grep_word_under_cursor()
  vim.cmd([[normal! "wyiw]])
  local word = vim.fn.getreg('"')
  fzf_lua.grep({
    cwd = git_or_cwd(),
    search = word,
    fn_selected = fn_selected_multi,
  })
end

--
---------- Files ----------
--
local function rg_files(rg_opts)
  local rg_cmd = ("rg %s --files --hidden %s"):format(rg_opts or "", rg_ignore_arg)
  return fzf_lua.fzf_exec(rg_cmd, {
    prompt = "Files > ",
    previewer = "builtin",
    cwd = git_or_cwd(),
    actions = fzf_actions,
    fn_transform = function(x)
      return fzf_lua.make_entry.file(x, { file_icons = true, color_icons = true })
    end,
  })
end

--
---------- LSP ----------
--
-- lsp issue with tips and tricks: https://github.com/ibhagwan/fzf-lua/issues/441
--
local function lsp_references()
  fzf_lua.lsp_references({
    async = true,
    file_ignore_patterns = { "miniconda3", "node_modules" }, -- ignore references in env libs
  })
end

--
------- Wax files -------

local function wax_files()
  local paths = {
    ".config/nvim/config.lua",
    ".gitconfig",
    ".python_startup_local.py",
    ".zshrc",
    "src/waxcraft/dotfiles",
    "src/nvim-treesitter",
    ".local/share/nvim/lazy",
  }
  local home = vim.env.HOME
  local abs_paths = vim.tbl_map(function(path)
    return home .. "/" .. path
  end, paths)

  local cmd = ("rg --hidden %s --files %s"):format(rg_ignore_arg, table.concat(abs_paths, " "))

  return fzf_lua.fzf_exec(cmd, {
    prompt = "WaxFiles > ",
    previewer = "builtin",
    cwd = vim.env.HOME,
    actions = fzf_actions,
    fn_transform = function(x)
      return fzf_lua.make_entry.file(x, { file_icons = true, color_icons = true })
    end,
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
    vim.cmd("stopinsert")
    if choice then
      fn(src_path:join(choice):absolute())
    end
  end)
end

local function select_project_find_file()
  pick_project(function(path)
    fzf_lua.files({ cwd = path })
  end)
end

local function select_project_fzf_grep()
  pick_project(function(path)
    fzf_lua.grep({ cwd = path, search = "" })
  end)
end

return {
  -- grep
  fzf_grep = fzf_grep,
  live_grep = live_grep,
  grep_word_under_cursor = grep_word_under_cursor,
  -- files
  rg_files = rg_files,
  -- lsp
  lsp_references = lsp_references,
  -- custom
  wax_files = wax_files,
  select_project_find_file = select_project_find_file,
  select_project_fzf_grep = select_project_fzf_grep,
}
