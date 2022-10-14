local fzf_lua = require("fzf-lua")

local scan = safe_require("plenary.scandir")
local Path = safe_require("plenary.path")

-- Example command launched by fzf-lua:

-- ```bash
--  fzf --expect=ctrl-v,ctrl-g,ctrl-s,alt-l,alt-q,ctrl-r,ctrl-t --multi --header=':: <^[[0;33mctrl-g^[[0m> to ^[[0;31mRegex Search^[[0m' --bind='alt-a:toggle-all,ctrl-a:beginning-of-line,ctrl-b:preview-page-up,ctrl-f:preview-page-down,shift-down:preview-page-down,ctrl-z:abort,ctrl-d:preview-page-down,shift-up:preview-page-up,f4:toggle-preview,ctrl-u:preview-page-up,f3:toggle-preview-wrap,ctrl-e:end-of-line' --preview=''\''/usr/local/bin/nvim'\'' -n --headless --clean --cmd '\''lua loadfile([[/Users/gjeusel/.local/share/nvim/site/pack/packer/start/fzf-lua/lua/fzf-lua/shell_helper.lua]])().rpc_nvim_exec_lua({fzf_lua_server=[[/var/folders/9_/mc8yjnyn1j3_15_wmktz0g6m0000gn/T/nvim.gjeusel/1RZQDr/nvim.31754.1]], fnc_id=1 , debug=true})'\'' {}' --border=none --print-query --height=100% --prompt='❯ ' --info=inline --layout=reverse --ansi --preview-window=nohidden:right:0
-- ```

local function grep_sel_to_qf(selected, opts)
  local qf_list = {}
  for i = 1, #selected do
    local file = fzf_lua.path.entry_to_file(selected[i], opts)
    local text = selected[i]:match(":%d+:%d?%d?%d?%d?:?(.*)$")
    table.insert(qf_list, {
      filename = file.bufname or file.path,
      lnum = file.line,
      col = file.col,
      text = text,
    })
  end
  log.warn("qf list:", qf_list)
  vim.fn.setqflist(qf_list, "r")
end

local function fn_selected_multi(selected, opts)
  if not selected then
    return
  end
  -- first element of "selected" is the keybind pressed
  if #selected < 2 then
    return fzf_lua.actions.act(opts.actions, selected, opts)
  else -- here we multi-selected
    local _, entries = fzf_lua.actions.normalize_selected(opts.actions, selected)
    grep_sel_to_qf(entries, opts)
    vim.cmd("cfirst")
  end
end

local fzf_actions = {
  ["default"] = fzf_lua.actions.file_edit,
  ["ctrl-s"] = fzf_lua.actions.file_split,
  ["ctrl-v"] = fzf_lua.actions.file_vsplit,
}

fzf_lua.setup({
  winopts = {
    height = 0.8,
    width = 0.9,
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
    -- fzf_opts = { ["--bind"] = "" },
    actions = fzf_actions,
    prompt = "❯ ",
    git_icons = false,
    file_icons = false,
    multiprocess = true,
    debug = true,
    show_cwd_header = false,
    rg_opts = table.concat({
      "--hidden --column --line-number --no-heading --color=always --smart-case",
      "-g '!{.git,.vscode}/*' -g '!{package-lock.json}'",
    }, " "),
  },
})

-- -- Register fzf-lua for vim.ui.select
fzf_lua.register_ui_select({}, true)
-- fzf_lua.deregister_ui_select({}, true)

local function git_or_cwd()
  local cwd = vim.loop.cwd()
  if is_git() then
    cwd = find_root_dir(cwd)
  end
  return cwd
end

local kmap = vim.keymap.set

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

local function rg_grep(rg_opts)
  local rg_cmd = ("rg %s --files --hidden --glob '!.git/'"):format(rg_opts or "")
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

-- Find Files
kmap("n", "<leader>p", rg_grep)

-- Find Git Files
kmap("n", "<leader>P", function()
  return rg_grep("--no-ignore-vcs")
end)

-- Fzf Lua Builtin
kmap("n", "<leader>fe", fzf_lua.builtin, { desc = "Fzf Lua Builtin" })

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
    file_ignore_patterns = { "miniconda3" }, -- ignore references in env libs
  })
end, { desc = "Fzf Lsp References" })

--
------- Wax files -------

local function list_wax_files()
  local paths = {
    "src/waxcraft/dotfiles",
    ".config/nvim/config.lua",
    ".local/share/nvim/site/pack/packer",
    ".gitconfig",
    ".python_startup_local.py",
    ".zshrc",
  }
  local home = vim.env.HOME

  local files = {}
  for _, path in pairs(paths) do
    path = Path:new(home .. "/" .. path)
    if path:is_file() then
      table.insert(files, path:make_relative(home))
    else
      local files_in_path = scan.scan_dir(path:absolute(), {
        hidden = true,
        add_dirs = false,
        only_dirs = false,
        respect_gitignore = true,
      })
      vim.list_extend(
        files,
        vim.tbl_map(function(e)
          return Path:new(e):make_relative(home)
        end, files_in_path)
      )
    end
  end

  return files
end

kmap("n", "<leader>fw", function()
  local files = list_wax_files()
  return fzf_lua.fzf_exec(files, {
    prompt = "WaxFiles > ",
    previewer = "builtin",
    cwd = vim.env.HOME,
    actions = fzf_actions,
    fn_transform = function(x)
      return fzf_lua.make_entry.file(x, { file_icons = true, color_icons = true })
    end,
  })
end)

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
end, { desc = "Pick project then find file" })

kmap("n", "<leader>Q", function()
  pick_project(function(path)
    fzf_lua.grep({ cwd = path, search = "" })
  end)
end, { desc = "Pick project then grep" })
