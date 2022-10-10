local fzf_lua = require("fzf-lua")

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
