local fzf_lua = require("fzf-lua")

local scan = safe_require("plenary.scandir")
local Path = safe_require("plenary.path")

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
      "--glob '!{.git,.vscode}/*' --glob '!{package-lock.json,*.svg,*weasytail.min.css}'",
    }, " "),
  },
})

-- Register fzf-lua for vim.ui.select
-- fzf_lua.register_ui_select({ winopts = { height = 0.33, width = 0.33 } }, true)
-- fzf_lua.deregister_ui_select({}, true)

--
------- utils funcs -------
--

local function git_or_cwd()
  local cwd = vim.fn.getcwd()
  if is_git() then
    cwd = find_root_dir_fn({ ".git" })(cwd)
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

local kmap = vim.keymap.set

--
---------- Grep ----------
--
-- Fzf Grep
kmap("n", "<leader>a", function()
  return fzf_lua.grep({
    cwd = git_or_cwd(),
    search = "",
    fn_selected = fn_selected_multi,
  })
end)

-- Live Grep
kmap("n", "<leader>A", function()
  return fzf_lua.live_grep({ cwd = git_or_cwd(), fn_selected = fn_selected_multi })
end)

-- Fzf Grep word under cursor
kmap("n", "<leader>ff", function()
  vim.cmd([[normal! "wyiw]])
  local word = vim.fn.getreg('"')
  fzf_lua.grep({
    cwd = git_or_cwd(),
    search = word,
    fn_selected = fn_selected_multi,
  })
end)

--
---------- Files ----------
--

local function rg_files(rg_opts)
  local ignore_dirs = { ".git", ".*_cache", "postgres-data", "edgedb-data", "__pycache__" }
  local ignore_files = { "weasytail.min.css" }

  local ignore_arg = ("--glob '!{%s}' --glob '!{%s}'"):format(
    table.concat(ignore_dirs, ","),
    table.concat(ignore_files, ",")
  )

  local rg_cmd = ("rg %s --files --hidden %s"):format(rg_opts or "", ignore_arg)
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

-- Find Files restricted
kmap("n", "<leader>p", rg_files, { desc = "Find git files" })

-- Find Files
kmap("n", "<leader>P", function()
  return rg_files("--no-ignore-vcs")
end, { desc = "Find files" })

--
---------- Misc ----------
--
-- Fzf Lua Builtin
kmap("n", "<leader>fe", fzf_lua.builtin, { desc = "Fzf Lua Builtin" })

kmap("n", "<leader>fh", function()
  vim.cmd([[normal! "wyiw]])
  local word = vim.fn.getreg('"')
  vim.cmd("vert h " .. word)
end, {
  desc = "Vertical split help for word under cursor",
})

-- Command History: option-d
kmap(
  { "n", "i", "c" },
  "∂", -- option + d
  fzf_lua.command_history,
  { desc = "Fzf Command History" }
)

-- Spell Suggest:
kmap("n", "z=", fzf_lua.spell_suggest, { desc = "Fzf Spell Suggest" })

-- Opened Buffers
kmap("n", "<leader>n", fzf_lua.buffers, { desc = "Fzf Opened Buffers" })

--
---------- LSP ----------
--
-- lsp issue with tips and tricks: https://github.com/ibhagwan/fzf-lua/issues/441
--
kmap("n", "<leader>r", function()
  fzf_lua.lsp_references({
    async = true,
    file_ignore_patterns = { "miniconda3", "node_modules" }, -- ignore references in env libs
  })
end, {
  desc = "Fzf Lsp References",
})

--
------- Wax files -------

kmap("n", "<leader>fw", function()
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

  local cmd = ("rg --hidden --glob '!{.git,}/' --files %s"):format(table.concat(abs_paths, " "))

  return fzf_lua.fzf_exec(cmd, {
    prompt = "WaxFiles > ",
    previewer = "builtin",
    cwd = vim.env.HOME,
    actions = fzf_actions,
    fn_transform = function(x)
      return fzf_lua.make_entry.file(x, { file_icons = true, color_icons = true })
    end,
  })
end, {
  desc = "Find file among dotfiles",
})

--
------- Project Select first -------

local function pick_project(fn)
  local base_path = vim.env.HOME .. "/src"
  local projects = scan.scan_dir(base_path, {
    hidden = false,
    add_dirs = true,
    only_dirs = true,
    depth = 1,
  })

  projects = vim.tbl_map(function(entry)
    return Path:new(entry):make_relative(base_path)
  end, projects)

  vim.ui.select(projects, { prompt = "Select project> " }, function(choice, _)
    if choice then
      local project = Path:new(base_path):joinpath(choice):absolute()
      fn(project)
    end
  end)
end

kmap("n", "<leader>q", function()
  pick_project(function(path)
    fzf_lua.files({ cwd = path })
  end)
end, {
  desc = "Pick project then find file",
})

kmap("n", "<leader>Q", function()
  pick_project(function(path)
    fzf_lua.grep({ cwd = path, search = "" })
  end)
end, {
  desc = "Pick project then grep",
})