local fzf_lua = require("fzf-lua")

local scan = safe_require("plenary.scandir")
local Path = safe_require("plenary.path")

-- Example command launched by fzf-lua:

-- ```bash
--  fzf --multi -n --headless --clean \
--    --expect=ctrl-v,ctrl-g,ctrl-s,alt-l,alt-q,ctrl-r,ctrl-t \
--    --header=':: <^[[0;33mctrl-g^[[0m> to ^[[0;31mRegex Search^[[0m' \
--    --bind='alt-a:toggle-all,ctrl-a:beginning-of-line,ctrl-b:preview-page-up,ctrl-f:preview-page-down,shift-down:preview-page-down,ctrl-z:abort,ctrl-d:preview-page-down,shift-up:preview-page-up,f4:toggle-preview,ctrl-u:preview-page-up,f3:toggle-preview-wrap,ctrl-e:end-of-line' \
--    --preview=''\''/usr/local/bin/nvim'\'' \
--    --cmd '\''lua loadfile([[/Users/gjeusel/.local/share/nvim/site/pack/packer/start/fzf-lua/lua/fzf-lua/shell_helper.lua]])().rpc_nvim_exec_lua({fzf_lua_server=[[/var/folders/9_/mc8yjnyn1j3_15_wmktz0g6m0000gn/T/nvim.gjeusel/1RZQDr/nvim.31754.1]], fnc_id=1 , debug=true})'\'' {}' \
--    --border=none --print-query --height=100% --prompt='❯ ' --info=inline --layout=reverse --ansi --preview-window=nohidden:right:0
-- ```

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
      "--glob '!{.git,.vscode}/*' --glob '!{package-lock.json,*.svg}'",
    }, " "),
  },
})

-- -- Register fzf-lua for vim.ui.select
-- fzf_lua.register_ui_select({}, true)
-- fzf_lua.deregister_ui_select({}, true)

-- custom vim.ui.select
vim.ui.select = function(items, opts, on_choice)
  -- exit visual mode if needed
  if not vim.api.nvim_get_mode() == "n" then
    fzf_lua.utils.feed_keys_termcodes("<Esc>")
  end

  local entries = vim.tbl_map(function(e)
    return opts.format_item and opts.format_item(e) or tostring(e)
  end, items)

  local prompt = opts.prompt or "Select> "

  local _opts = {
    fzf_opts = {
      ["--no-multi"] = "",
      ["--prompt"] = prompt:gsub(":%s?$", "> "),
      ["--preview-window"] = "hidden:right:0",
    },
    actions = {
      ["default"] = function(selected)
        for i, e in ipairs(entries) do
          if e == selected[1] then
            return on_choice(items[i], i)
          end
        end
      end,
    },
  }
  fzf_lua.core.fzf_exec(entries, _opts)
end

--
------- utils funcs -------
--

local function git_or_cwd()
  local cwd = vim.loop.cwd()
  if is_git() then
    cwd = find_root_dir_fn({ ".git" })(cwd)
  end
  return cwd
end

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
  vim.fn.setqflist(qf_list, "r")
end

local function fn_selected_multi(selected, opts)
  if not selected then
    return
  end

  -- first element of "selected" is the keybind pressed
  if #selected <= 2 then
    fzf_lua.actions.act(opts.actions, selected, opts)
  else -- here we multi-selected
    local _, entries = fzf_lua.actions.normalize_selected(opts.actions, selected)
    grep_sel_to_qf(entries, opts)
    vim.cmd("cfirst")
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
  local ignore_files = {}

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
kmap("n", "<leader>p", rg_files)

-- Find Files
kmap("n", "<leader>P", function()
  return rg_files("--no-ignore-vcs")
end)

--
---------- Misc ----------
--
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
    ".local/share/nvim/site/pack/packer",
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
