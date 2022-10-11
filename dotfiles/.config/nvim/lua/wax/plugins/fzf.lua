local fzf_lua = require("fzf-lua")

-- Example command launched by fzf-lua:

-- ```bash
--  fzf --expect=ctrl-v,ctrl-g,ctrl-s,alt-l,alt-q,ctrl-r,ctrl-t --multi --header=':: <^[[0;33mctrl-g^[[0m> to ^[[0;31mRegex Search^[[0m' --bind='alt-a:toggle-all,ctrl-a:beginning-of-line,ctrl-b:preview-page-up,ctrl-f:preview-page-down,shift-down:preview-page-down,ctrl-z:abort,ctrl-d:preview-page-down,shift-up:preview-page-up,f4:toggle-preview,ctrl-u:preview-page-up,f3:toggle-preview-wrap,ctrl-e:end-of-line' --preview=''\''/usr/local/bin/nvim'\'' -n --headless --clean --cmd '\''lua loadfile([[/Users/gjeusel/.local/share/nvim/site/pack/packer/start/fzf-lua/lua/fzf-lua/shell_helper.lua]])().rpc_nvim_exec_lua({fzf_lua_server=[[/var/folders/9_/mc8yjnyn1j3_15_wmktz0g6m0000gn/T/nvim.gjeusel/1RZQDr/nvim.31754.1]], fnc_id=1 , debug=true})'\'' {}' --border=none --print-query --height=100% --prompt='❯ ' --info=inline --layout=reverse --ansi --preview-window=nohidden:right:0
-- ```

fzf_lua.setup({
  winopts = { height = 0.8, width = 0.9 },
  keymap = {
    builtin = {
      ["<ctrl-d>"] = "preview-page-down",
      ["<ctrl-u>"] = "preview-page-up",
    },
    fzf = {
      -- fzf '--bind=' options
      -- -- NOTE: not working
      -- ["ctrl-d"] = "preview-page-down",
      -- ["ctrl-u"] = "preview-page-up",
    },
  },
  grep = {
    actions = {
      ["default"] = fzf_lua.actions.file_edit,
      ["ctrl-s"] = fzf_lua.actions.file_split,
      ["ctrl-v"] = fzf_lua.actions.file_vsplit,
      ["ctrl-r"] = fzf_lua.actions.file_sel_to_ll, -- not working neither
    },
  },
})

local opts = {
  prompt = "❯ ",
  git_icons = false,
  file_icons = false,
  multiprocess = true,
  debug = true,
  show_cwd_header = false,
  rg_opts = "--hidden --column --line-number --no-heading --color=always --smart-case "
    .. "-g '!{.git,.vscode}/*' -g '!{package-lock.json}'",
}

local git_or_cwd = function()
  local cwd = vim.loop.cwd()
  if is_git() then
    cwd = find_root_dir(cwd)
  end
  return cwd
end

vim.keymap.set("n", "<leader>a", function()
  return fzf_lua.grep(vim.tbl_extend("force", opts, { cwd = git_or_cwd(), search = "" }))
end)

vim.keymap.set("n", "<leader>A", function()
  return fzf_lua.live_grep(vim.tbl_extend("force", opts, { cwd = git_or_cwd() }))
end)
